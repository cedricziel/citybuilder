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
    for kind in ["grass", "beach", "water", "forest", "mountain"] {
        #expect(contents.contains("terrain-\(kind).png"), "terrain-\(kind).png")
    }
    let retired = worktreeRoot().appendingPathComponent("Resources/Terrain.atlas")
    #expect(!FileManager.default.fileExists(atPath: retired.path))
}

@Test("scenario: buildings atlas exists")
func scenarioBuildingsAtlasExists() {
    let url = worktreeRoot().appendingPathComponent("Resources/Buildings.atlas")
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    #expect(exists && isDir.boolValue, "Resources/Buildings.atlas must exist as a directory")
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    #expect(contents.contains(where: { $0.hasPrefix("building-") && $0.hasSuffix(".png") }))
}

@Test("scenario: units atlas exists")
func scenarioUnitsAtlasExists() {
    let url = worktreeRoot().appendingPathComponent("Resources/Units.atlas")
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    #expect(exists && isDir.boolValue, "Resources/Units.atlas must exist as a directory")
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    #expect(contents.contains(where: { $0.hasPrefix("walker-") && $0.hasSuffix(".png") }))
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
    for kind in TerrainType.allCases {
        let count = SpriteAtlas.terrainVariantCounts[kind] ?? 1
        for variant in 0 ..< count {
            names.insert(SpriteAtlas.variantAssetName(stem: "terrain-\(kind.rawValue)", variant: variant))
        }
        let frames = SpriteAnimation.entry(for: .terrain(kind))?.frameCount ?? 0
        names.formUnion((0 ..< frames).map { SpriteAnimation.assetName(for: .terrain(kind), frame: $0) })
        for season in Season.allCases {
            guard let seasonal = IsoWorldScene.seasonalTerrainName(kind: kind, season: season) else { continue }
            names.insert(seasonal)
            names.formUnion((0 ..< frames).map { "\(seasonal)-\($0)" })
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
    #expect(names.count >= 80 + 94) // terrain: 16 tiles and frames, 8 seasonal, 56 transitions; roads: 47 masks x 2
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
/// construction stages and every operational frame. Stems without a building kind (house tiers,
/// road connection sets) are covered by their own tests.
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
    // Culture looks are finished-only: the base and, for kinds with a loop, its operational frames.
    var looks = 0
    for kind in IsoWorldScene.cultureVariantKinds.sorted(by: { $0.rawValue < $1.rawValue }) {
        for culture in Culture.allCases {
            guard let look = IsoWorldScene.cultureTextureName(kind: kind, houseTier: .peasants, culture: culture),
                  TextureFiltering.kitRenderedStems.contains(look)
            else { continue }
            looks += 1
            names.append(look)
            let frames = SpriteAnimation.entry(for: .buildingOperational(kind))?.frameCount ?? 0
            names += (0 ..< frames).map { "\(look)-operational-\($0)" }
        }
    }
    // Shore buildings draw one look per facing (`-n/-e/-s/-w`), each with its stages and frames.
    var facings = 0
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
    // Ships draw one look per heading, two sail frames each.
    for facing in ShipFacing.allCases where TextureFiltering.kitRenderedStems.contains("ship-\(facing.rawValue)") {
        facings += 1
        names += (0 ..< 2).map { ShipRenderMath.textureName(facing: facing, frame: $0) }
    }
    // Every migrated kind contributes its base and three construction stages at least, so the walk
    // can never pass by checking nothing.
    #expect(!kinds.isEmpty)
    #expect(looks >= 6, "the warehouse and library looks of three cultures")
    #expect(facings >= 16, "the port and shipyard in four facings, the ship in eight")
    #expect(names.count >= kinds.count * 4 + looks + facings * 2)
    let missing = names.sorted().flatMap { name -> [String] in
        let atlas = SpriteAtlasRouting.atlasName(for: name) ?? "?"
        return ["\(name).png", "\(name)@2x.png"].compactMap { file in
            let path = resources.appendingPathComponent("\(atlas).atlas/\(file)").path
            return FileManager.default.fileExists(atPath: path) ? nil : "\(atlas).atlas/\(file)"
        }
    }
    #expect(missing.isEmpty, "\(missing)")
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
