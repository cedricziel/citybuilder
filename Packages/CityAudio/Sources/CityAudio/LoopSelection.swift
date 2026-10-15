import CityCore

/// Which wanted loops play: the `limit` nearest the listener. Loops
/// without a position, and every loop when there is no listener yet,
/// rank after placed ones, in entity order so the choice is stable. A
/// playing loop counts `margin` tiles nearer than it is, so panning along
/// the boundary doesn't swap loops back and forth.
/// Spec: `audio-playback` / Loop players follow their buildings.
enum LoopSelection {
    static let defaultLimit = 8
    static let defaultMargin = 3.0

    static func audible(
        _ wanted: [EntityID: TileCoordinate?],
        listener: TileCoordinate?,
        playing: Set<EntityID> = [],
        limit: Int = defaultLimit,
        margin: Double = defaultMargin
    ) -> Set<EntityID> {
        func rank(_ entity: EntityID, _ tile: TileCoordinate?) -> Double {
            guard let tile else { return .infinity }
            guard let listener else { return .greatestFiniteMagnitude }
            let dx = Double(tile.x - listener.x)
            let dy = Double(tile.y - listener.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            return playing.contains(entity) ? distance - margin : distance
        }
        let ranked = wanted.map { (entity: $0.key, rank: rank($0.key, $0.value)) }
            .sorted { $0.rank == $1.rank ? $0.entity.raw < $1.entity.raw : $0.rank < $1.rank }
        return Set(ranked.prefix(limit).map(\.entity))
    }
}
