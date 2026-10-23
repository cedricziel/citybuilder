import CityCore
import SpriteKit

/// What the ground macro field is built from (terrain-v2, design D1).
public struct GroundMacroInputs: Sendable {
    public let width: Int
    public let height: Int
    public let grid: [TerrainType]
    public let occupied: Set<TileCoordinate>
    public let season: Season

    public func build() -> GroundMacroField {
        GroundMacroField(width: width, height: height, grid: grid, occupied: occupied, season: season)
    }
}

/// Tells the scene when to rebuild the macro field: only when the terrain, the occupied tiles or the
/// season's look changed. Spring and summer share a look.
public struct GroundMacroCache {
    private var size: (width: Int, height: Int)?
    private var grid: [TerrainType]?
    private var occupancy: [TileCoordinate: EntityID]?
    private var look: Season?
    public private(set) var computations = 0

    public init() {}

    /// The inputs of a new field when something it depends on changed since the last call, else nil.
    public mutating func inputs(for snapshot: WorldSnapshot) -> GroundMacroInputs? {
        let look = GroundMacroField.Look.season(of: snapshot.date.season)
        let mapSize = (width: snapshot.mapWidth, height: snapshot.mapHeight)
        guard size.map({ $0 != mapSize }) ?? true || grid != snapshot.terrainGrid || occupancy != snapshot.occupiedTiles
            || self.look != look
        else { return nil }
        size = mapSize
        grid = snapshot.terrainGrid
        occupancy = snapshot.occupiedTiles
        self.look = look
        computations += 1
        return GroundMacroInputs(
            width: snapshot.mapWidth, height: snapshot.mapHeight, grid: snapshot.terrainGrid,
            occupied: Set(snapshot.occupiedTiles.keys), season: look
        )
    }
}

extension GroundMacroField {
    /// The field as a linearly filtered texture, top row first.
    func texture() -> SKTexture {
        texture(of: pixels)
    }

    /// The scree cover as a linearly filtered texture, top row first.
    func screeTexture() -> SKTexture {
        texture(of: screePixels)
    }

    private func texture(of pixels: [UInt8]) -> SKTexture {
        let texture = SKTexture(data: Data(pixels), size: CGSize(width: width, height: height), flipped: true)
        texture.filteringMode = .linear
        return texture
    }
}

extension IsoWorldScene {
    public static let groundMacroNodeName = "ground-macro"
    public static let groundScreeNodeName = "ground-scree"

    /// Multiplies the macro field over the ground tiles (z 0), under objects and buildings (z >= 10).
    /// Fields build off the main thread, one at a time and at most every quarter second, so neither
    /// the title backdrop nor a harvested forest tile stalls a frame; the ground shows unmultiplied
    /// until the first one lands. Requests that arrive meanwhile collapse into the latest.
    func reconcileGround(with snapshot: WorldSnapshot) {
        guard let inputs = groundMacroCache.inputs(for: snapshot) else { return }
        groundMacroPending = inputs
        buildPendingGroundMacro()
    }

    /// The gap between the end of one build and the start of the next.
    nonisolated static let groundMacroRebuildInterval: Duration = .milliseconds(250)

    private func buildPendingGroundMacro() {
        guard !groundMacroBuilding, let inputs = groundMacroPending else { return }
        groundMacroPending = nil
        groundMacroBuilding = true
        Task.detached(priority: .utility) { [weak self] in
            let field = inputs.build()
            await self?.show(field, from: inputs)
            try? await Task.sleep(for: Self.groundMacroRebuildInterval)
            await self?.finishGroundMacroBuild()
        }
    }

    private func finishGroundMacroBuild() {
        groundMacroBuilding = false
        buildPendingGroundMacro()
    }

    private func show(_ field: GroundMacroField, from inputs: GroundMacroInputs) {
        groundMacroShown = inputs
        let size = CGSize(
            width: CGFloat(field.width) * GroundMacroField.pointsPerTexel,
            height: CGFloat(field.height) * GroundMacroField.pointsPerTexel
        )
        // Scree lies on rock ground under the macro field, which then tints it like everything else.
        for (name, texture, blend, zPosition) in [
            (Self.groundScreeNodeName, field.screeTexture(), SKBlendMode.alpha, CGFloat(0.5)),
            (Self.groundMacroNodeName, field.texture(), .multiplyX2, 1)
        ] {
            let node = childNode(withName: name) as? SKSpriteNode ?? {
                let node = SKSpriteNode()
                node.name = name
                node.anchorPoint = CGPoint(x: 0, y: 1)
                node.blendMode = blend
                node.zPosition = zPosition
                addChild(node)
                return node
            }()
            node.texture = texture
            node.size = size
            node.position = field.topLeft
        }
    }
}
