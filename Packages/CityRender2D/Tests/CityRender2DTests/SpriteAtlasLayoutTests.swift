#if canImport(AppKit)
import CityCore
import Foundation
import Testing
@testable import CityRender2D

// Filesystem + code-scan scenarios for the sprite-asset-pipeline and
// rendering-2_5d capabilities introduced by add-sprite-atlas-layout.
// Each `#### Scenario:` here is one filesystem or static check against
// the worktree on disk.

private func worktreeRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityRender2DTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
}

@Test("scenario: terrain atlas exists")
func scenarioTerrainAtlasExists() {
    let kit = worktreeRoot().appendingPathComponent("Resources/Kit.atlas")
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: kit.path)) ?? []
    for kind in ["grass", "beach", "water"] {
        #expect(contents.contains("terrain-\(kind).png"), "terrain-\(kind).png")
    }
    // Forest and mountain stand on grass: their trees and rocks are objects, with no ground tile.
    #expect(!contents.contains("terrain-forest.png") && !contents.contains("terrain-mountain.png"))
    let retired = worktreeRoot().appendingPathComponent("Resources/Terrain.atlas")
    #expect(!FileManager.default.fileExists(atPath: retired.path))
}

@Test("scenario: Retired atlases are gone")
func scenarioRetiredAtlasesAreGone() throws {
    // Terrain, buildings, people, ships and goods icons are kit renders in Kit.atlas; the badges are in Icons.atlas.
    for retired in ["Terrain", "Buildings", "Units"] {
        let url = worktreeRoot().appendingPathComponent("Resources/\(retired).atlas")
        #expect(!FileManager.default.fileExists(atPath: url.path), "Resources/\(retired).atlas must not exist")
    }
    let atlases = try FileManager.default.contentsOfDirectory(atPath: worktreeRoot().appendingPathComponent("Resources").path)
        .filter { $0.hasSuffix(".atlas") }.sorted()
    #expect(atlases == ["Icons.atlas", "Kit.atlas"])
}

@Test("scenario: legacy sprite directory removed")
func scenarioLegacySpriteDirectoryRemoved() {
    let url = worktreeRoot().appendingPathComponent("Resources/Sprites")
    #expect(!FileManager.default.fileExists(atPath: url.path), "Resources/Sprites/ must not exist")
}

@Test("scenario: renderer source uses spriteatlas exclusively")
func scenarioRendererSourceUsesSpriteAtlasExclusively() throws {
    // Code-scan every .swift file under Packages/CityRender2D/Sources/
    // and confirm none calls `SKTexture(imageNamed:` for catalogued
    // sprite assets. Comments are stripped before the check so doc
    // text mentioning the forbidden call (in a "never use this"
    // context) doesn't trip the gate.
    let root = worktreeRoot()
        .appendingPathComponent("Packages/CityRender2D/Sources/CityRender2D")
    let enumerator = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: nil
    )
    var violations: [String] = []
    while let url = enumerator?.nextObject() as? URL {
        guard url.pathExtension == "swift" else { continue }
        let source = try String(contentsOf: url, encoding: .utf8)
        let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        if codeLines.contains("SKTexture(imageNamed:") {
            violations.append(url.lastPathComponent)
        }
    }
    if !violations.isEmpty {
        Issue.record(
            "files calling SKTexture(imageNamed:) directly: \(violations.joined(separator: ", "))"
        )
    }
    #expect(violations.isEmpty)
}

/// Every terrain name the renderer can ask for, in every season: base tiles and their animation
/// frames, rock variants, seasonal tiles and their frames, and each transition with its seasonal sets.
@MainActor
private func terrainNamesTheRendererRequests() -> Set<String> {
    var names: Set<String> = []
    for kind in TerrainType.allCases where !TerrainObject.kinds.contains(kind) {
        let count = SpriteAtlas.terrainVariantCounts[kind] ?? 1
        let frames = SpriteAnimation.entry(for: .terrain(kind))?.frameCount ?? 0
        let looks = ["terrain-\(kind.rawValue)"] + Season.allCases.compactMap { IsoWorldScene.seasonalTerrainName(kind: kind, season: $0) }
        for look in looks {
            for variant in 0 ..< count {
                let name = SpriteAtlas.variantAssetName(stem: look, variant: variant)
                names.insert(name)
                names.formUnion((0 ..< frames).map { "\(name)-\($0)" })
            }
        }
    }
    for pair in SpriteName.transitionPairs {
        let parts = pair.split(separator: "-").map(String.init)
        guard let upper = TerrainType(rawValue: parts[0]), let lower = TerrainType(rawValue: parts[1]) else { continue }
        for mask in 1 ... 14 {
            let transition = TerrainTransition(upper: upper, lower: lower, mask: mask)
            names.formUnion(Season.allCases.map { transition.assetName(in: $0) })
        }
    }
    return names
}

/// The reverse of the check below: nothing the renderer requests may fall back to the placeholder.
@MainActor
@Test("every terrain and road sprite the renderer can request is committed where it routes")
func everyRequestedTerrainSpriteIsOnDisk() {
    let resources = worktreeRoot().appendingPathComponent("Resources")
    let roads = RoadLinks.allMasks.flatMap { mask in [false, true].map { RoadLink(mask: mask, plaza: $0).assetName } }
    let names = terrainNamesTheRendererRequests().union(roads)
    // terrain: 36 grass looks (3 seasons x 4 variants x base and 2 frames), 8 beach and water tiles and
    // frames, 56 transitions; roads: 47 masks x 2
    #expect(names.count >= 100 + 94)
    let missing = names.sorted().flatMap { name -> [String] in
        let atlas = SpriteAtlasRouting.atlasName(for: name) ?? "?"
        return ["\(name).png", "\(name)@2x.png"].compactMap { file in
            let path = resources.appendingPathComponent("\(atlas).atlas/\(file)").path
            return FileManager.default.fileExists(atPath: path) ? nil : "\(atlas).atlas/\(file)"
        }
    }
    #expect(missing.isEmpty, "\(missing)")
}

/// Every sprite the renderer can request for a kit-rendered building stem: the base, its three
/// construction stages and every operational frame, plus the culture and age looks, the shore
/// facings and the ship headings.
@MainActor
@Test("every building sprite the renderer can request is committed where it routes")
func everyRequestedBuildingSpriteIsOnDisk() {
    let resources = worktreeRoot().appendingPathComponent("Resources")
    let kinds = TextureFiltering.kitRenderedStems.compactMap { stem in
        stem.hasPrefix("building-") ? BuildingKind(rawValue: String(stem.dropFirst("building-".count))) : nil
    }
    var names: [String] = []
    for kind in kinds {
        names.append("building-\(kind.rawValue)")
        let stages = SpriteAnimation.entry(for: .buildingConstructing(kind))?.frameCount ?? 0
        names += (0 ..< stages).map { SpriteAnimation.assetName(for: .buildingConstructing(kind), frame: $0) }
        let frames = SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount ?? 0
        names += (0 ..< frames).map { SpriteAnimation.assetName(for: .buildingOperational(kind), frame: $0) }
    }
    let (looks, lookNames) = cultureLookSprites(), (ages, ageNames) = ageLookSprites(), (facings, facingNames) = facingSprites()
    names += lookNames + ageNames + facingNames
    // Every migrated kind contributes its base and three construction stages at least, so the walk
    // can never pass by checking nothing.
    #expect(!kinds.isEmpty)
    #expect(looks == 18, "the house tiers, town center, warehouse and library looks of three cultures")
    #expect(ages == 48, "three house tiers in four ages and four cultures")
    #expect(facings >= 16, "the port and shipyard in four facings, the ship in eight")
    #expect(names.count >= kinds.count * 4 + looks + ages + facings * 2)
    let missing = names.sorted().flatMap { name -> [String] in
        let atlas = SpriteAtlasRouting.atlasName(for: name) ?? "?"
        return ["\(name).png", "\(name)@2x.png"].compactMap { file in
            let path = resources.appendingPathComponent("\(atlas).atlas/\(file)").path
            return FileManager.default.fileExists(atPath: path) ? nil : "\(atlas).atlas/\(file)"
        }
    }
    #expect(missing.isEmpty, "\(missing)")
}

/// Culture looks are finished-only: the base and, for kinds with a loop, its operational frames.
@MainActor
private func cultureLookSprites() -> (looks: Int, names: [String]) {
    var looks = 0, names: [String] = []
    for kind in IsoWorldScene.cultureVariantKinds.sorted(by: { $0.rawValue < $1.rawValue }) {
        for culture in Culture.allCases {
            for tier in kind == .house ? HouseTier.allCases : [.peasants] {
                guard let look = IsoWorldScene.cultureTextureName(kind: kind, houseTier: tier, culture: culture),
                      TextureFiltering.kitRenderedStems.contains(look)
                else { continue }
                looks += 1
                names.append(look)
                let frames = SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount ?? 0
                names += (0 ..< frames).map { "\(look)-operational-\($0)" }
            }
        }
    }
    return (looks, names)
}

/// Houses also follow the age: the most specific look name (age and culture) for every tier.
@MainActor
private func ageLookSprites() -> (looks: Int, names: [String]) {
    let names = Age.allCases.filter { $0 != .medieval }.flatMap { age in
        Culture.allCases.flatMap { culture in
            HouseTier.allCases.compactMap { tier in IsoWorldScene.houseLookNames(houseTier: tier, culture: culture, age: age).first }
        }
    }.filter(TextureFiltering.kitRenderedStems.contains)
    return (names.count, names)
}

/// Shore buildings draw one look per facing (`-n/-e/-s/-w`) with its stages and frames; ships one
/// look per heading, two sail frames each.
private func facingSprites() -> (facings: Int, names: [String]) {
    var facings = 0, names: [String] = []
    for kind in BuildingKind.allCases where BuildingCatalog.spec(for: kind).shorePlacement != nil {
        for orientation in ShoreOrientation.allCases {
            let base = ShoreOrientationMath.textureName(kind: kind, orientation: orientation, state: nil, frame: nil)
            guard TextureFiltering.kitRenderedStems.contains(base) else { continue }
            facings += 1
            names.append(base)
            for (state, animation) in [
                (BuildingState.constructing, SpriteAnimation.AnimationKey.buildingConstructing(kind)),
                (.operational, .buildingOperational(kind))
            ] {
                // With no operational loop the renderer still draws a finished one as `-operational-0`.
                let frames = SpriteAnimation.entry(for: animation)?.frameCount ?? (state == .operational ? 1 : 0)
                names += (0 ..< frames).map {
                    ShoreOrientationMath.textureName(kind: kind, orientation: orientation, state: state, frame: $0)
                }
            }
        }
    }
    for facing in ShipFacing.allCases where TextureFiltering.kitRenderedStems.contains("ship-\(facing.rawValue)") {
        facings += 1
        names += (0 ..< 2).map { ShipRenderMath.textureName(facing: facing, frame: $0) }
    }
    return (facings, names)
}

/// Houses and workshops glow at night through `<stem>-lights-<n>`, added over the sprite: every house
/// look ships each variant at both scales, and every lights file sits beside the sprite it lights.
@Test("scenario: Every house look ships its lights")
func nightLightsAreCommitted() throws {
    let kit = worktreeRoot().appendingPathComponent("Resources/Kit.atlas")
    let files = try Set(FileManager.default.contentsOfDirectory(atPath: kit.path))
    let houses = TextureFiltering.kitRenderedStems.filter { $0.hasPrefix("building-house") }
    #expect(houses.count == 60, "three base tiers, nine culture looks, 48 age looks")
    let variants = 0 ..< WindowLights.variants
    let unlit = houses.filter { house in
        variants.contains { !files.contains("\(house)-lights-\($0).png") || !files.contains("\(house)-lights-\($0)@2x.png") }
    }
    #expect(unlit.isEmpty, "house looks without all their night lights: \(unlit.sorted())")
    let lights = files.filter { $0.range(of: #"-lights-\d+\.png$"#, options: .regularExpression) != nil }
    // The workshops with a window you can see. The smelter, steam engine and sawmill show none,
    // so they get no lights rather than a mask that never glows.
    let workshops = Set(lights.map { String($0[..<$0.range(of: "-lights-")!.lowerBound]) }.filter { !$0.hasPrefix("building-house") })
    #expect(workshops == [
        "building-bakery", "building-brewery", "building-charcoal-burner", "building-power-plant", "building-quern-house",
        "building-roastery", "building-toolsmith", "building-weaver", "building-windmill", "building-winery"
    ])
    for dark in ["building-smelter", "building-steam-engine", "building-sawmill"] {
        #expect(!files.contains { $0.hasPrefix("\(dark)-lights") }, "\(dark) has no visible window")
    }
    let orphans = lights.filter { name in
        let lit = String(name.dropLast(".png".count))
        let sprite = String(lit[..<lit.range(of: "-lights-", options: .backwards)!.lowerBound])
        return !files.contains("\(sprite).png") || !files.contains("\(lit)@2x.png")
    }
    #expect(orphans.isEmpty, "lights without their sprite or @2x twin: \(orphans.sorted())")
    #expect(SpriteAtlasRouting.atlasName(for: "building-bakery-lights-0") == "Kit")
    #expect(SpriteAtlasRouting.atlasName(for: "building-house-tier2-modern-east-asian-lights-2") == "Kit")
}

/// Routing and the committed files must agree. A stem listed as kit-rendered with a frame left in
/// Buildings, or a render written to Kit.atlas without its stem listed, would pass every other test
/// and then draw the placeholder or never blend.
@Test("every committed atlas PNG sits in the atlas its name routes to")
func everyAtlasPNGSitsWhereItRoutes() throws {
    let resources = worktreeRoot().appendingPathComponent("Resources")
    let atlases = try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "atlas" }
    var misplaced: [String] = []
    var checked = 0
    for atlas in atlases {
        let folder = atlas.deletingPathExtension().lastPathComponent
        let files = try FileManager.default.contentsOfDirectory(at: atlas, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "png" {
            let name = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "@2x", with: "")
            let routed = SpriteAtlasRouting.atlasName(for: name)
            checked += 1
            if routed != folder { misplaced.append("\(folder).atlas/\(file.lastPathComponent) routes to \(routed ?? "nothing")") }
        }
    }
    #expect(checked > 300)
    #expect(misplaced.isEmpty, "\(misplaced)")
}
#endif
