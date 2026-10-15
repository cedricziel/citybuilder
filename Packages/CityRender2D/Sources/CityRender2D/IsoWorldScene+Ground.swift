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
    private var grid: [TerrainType]?
    private var occupancy: [TileCoordinate: EntityID]?
    private var look: Season?
    public private(set) var computations = 0

    public init() {}

    /// The inputs of a new field when something it depends on changed since the last call, else nil.
    public mutating func inputs(for snapshot: WorldSnapshot) -> GroundMacroInputs? {
        let look = GroundMacroField.Look.season(of: snapshot.date.season)
        guard grid != snapshot.terrainGrid || occupancy != snapshot.occupiedTiles || self.look != look else { return nil }
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
        let texture = SKTexture(data: Data(pixels), size: CGSize(width: width, height: height), flipped: true)
        texture.filteringMode = .linear
        return texture
    }
}

extension IsoWorldScene {
    public static let groundMacroNodeName = "ground-macro"

    /// Multiplies the macro field over the ground tiles (z 0), under objects and buildings (z >= 10).
    /// The first field is built at once; later ones off the main thread, one at a time, so a harvested
    /// forest tile or a new house never stalls a frame. Requests that arrive meanwhile collapse into
    /// the latest one, built when the current build is shown.
    func reconcileGround(with snapshot: WorldSnapshot) {
        guard let inputs = groundMacroCache.inputs(for: snapshot) else { return }
        guard childNode(withName: Self.groundMacroNodeName) != nil else {
            show(inputs.build())
            return
        }
        groundMacroPending = inputs
        buildPendingGroundMacro()
    }

    private func buildPendingGroundMacro() {
        guard !groundMacroBuilding, let inputs = groundMacroPending else { return }
        groundMacroPending = nil
        groundMacroBuilding = true
        Task.detached(priority: .utility) {
            let field = inputs.build()
            await MainActor.run { [weak self] in
                guard let self else { return }
                groundMacroBuilding = false
                show(field)
                buildPendingGroundMacro()
            }
        }
    }

    private func show(_ field: GroundMacroField) {
        let node = childNode(withName: Self.groundMacroNodeName) as? SKSpriteNode ?? {
            let node = SKSpriteNode()
            node.name = Self.groundMacroNodeName
            node.anchorPoint = CGPoint(x: 0, y: 1)
            node.blendMode = .multiplyX2
            node.zPosition = 1
            addChild(node)
            return node
        }()
        node.texture = field.texture()
        node.size = CGSize(
            width: CGFloat(field.width) * GroundMacroField.pointsPerTexel,
            height: CGFloat(field.height) * GroundMacroField.pointsPerTexel
        )
        node.position = field.topLeft
    }
}
