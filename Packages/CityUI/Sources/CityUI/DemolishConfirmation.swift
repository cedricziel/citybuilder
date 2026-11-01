import CityCore
import SwiftUI

/// A demolish waiting for the player's yes. Spec: `platform-shells` /
/// Demolish asks first.
public struct DemolishRequest: Equatable, Sendable {
    public let tile: TileCoordinate
    public let kind: BuildingKind
    public let refund: Int64

    /// "Demolish Sawmill?"
    public var title: String {
        GameText.string("demolish.confirm.title", kind.displayName)
    }

    /// "You get $60 back.", or "You get nothing back."
    public var message: String {
        refund > 0
            ? GameText.string("demolish.confirm.refund", HUDViewModel.formatMoney(refund))
            : GameText.string("demolish.confirm.noRefund")
    }
}

extension GameSession {
    /// The confirmation a demolish at `tile` needs: one for the player's
    /// standing buildings other than a road. Roads, ruins and a burning
    /// building go at once.
    func demolishConfirmation(at tile: TileCoordinate) -> DemolishRequest? {
        guard let id = world.occupiedTiles[tile], let building = world.buildings[id], building.owner == .player,
              building.kind != .road, building.kind != .ruins, building.state != .burning
        else { return nil }
        return DemolishRequest(tile: tile, kind: building.kind, refund: World.demolitionRefund(for: building))
    }

    /// Demolishes at `tile`, asking first where a standing building would go.
    func requestDemolish(at tile: TileCoordinate) {
        guard !isGameOver else { return }
        if let request = demolishConfirmation(at: tile) {
            demolishRequest = request
        } else {
            enqueue(.demolish(at: tile))
        }
    }

    /// The player said yes: demolishes, and drops the selection when it
    /// was the demolished building.
    public func confirmDemolish() {
        guard let request = demolishRequest else { return }
        demolishRequest = nil
        enqueue(.demolish(at: request.tile))
        if let selectedTile, world.occupiedTiles[selectedTile] == world.occupiedTiles[request.tile] {
            self.selectedTile = nil
        }
    }

    public func cancelDemolish() {
        demolishRequest = nil
    }
}

extension View {
    /// The demolish confirmation on the game screen, on every platform.
    func demolishConfirmation(session: GameSession) -> some View {
        alert(
            session.demolishRequest?.title ?? "",
            isPresented: Binding(
                get: { session.demolishRequest != nil },
                set: { if !$0 { session.cancelDemolish() } }
            ),
            presenting: session.demolishRequest
        ) { _ in
            Button(GameText.string("tool.demolish"), role: .destructive, action: session.confirmDemolish)
            Button(GameText.string("common.cancel"), role: .cancel, action: session.cancelDemolish)
        } message: { request in
            Text(request.message)
        }
    }
}
