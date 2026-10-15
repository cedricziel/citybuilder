import CityCore

/// Which wanted loops play: the `limit` nearest the listener. Loops
/// without a position, and every loop when there is no listener yet,
/// rank after placed ones, in entity order so the choice is stable.
/// Spec: `audio-playback` / Loop players follow their buildings.
enum LoopSelection {
    static let defaultLimit = 8

    static func audible(
        _ wanted: [EntityID: TileCoordinate?],
        listener: TileCoordinate?,
        limit: Int = defaultLimit
    ) -> Set<EntityID> {
        func distance(_ tile: TileCoordinate?) -> Int {
            guard let tile else { return .max }
            guard let listener else { return .max - 1 }
            let dx = tile.x - listener.x
            let dy = tile.y - listener.y
            return dx * dx + dy * dy
        }
        let ranked = wanted.sorted { lhs, rhs in
            let (left, right) = (distance(lhs.value), distance(rhs.value))
            return left == right ? lhs.key.raw < rhs.key.raw : left < right
        }
        return Set(ranked.prefix(limit).map(\.key))
    }
}
