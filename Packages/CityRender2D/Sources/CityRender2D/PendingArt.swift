import CityCore
import Foundation

/// Building kinds the simulation has but the art doesn't yet: their catalog
/// briefs say `source = "pending"`, the renderer draws the missing-sprite
/// placeholder, and the build palette hides them. Task 8.1 of
/// `add-event-counterplay` draws them and empties this set; a test fails
/// once a kind here has committed sprites.
public enum PendingArt {
    public static let buildingKinds: Set<BuildingKind> = []
}
