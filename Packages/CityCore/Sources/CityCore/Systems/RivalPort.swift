import Foundation

/// The rival port rule. Spec: `rival-trade` / Rivals build a port
/// (design D1).
extension RivalAI {
    static let portMinHouses = 6
    /// Chebyshev radius of the port search around the town center.
    static let portSearchRadius = 40
    static let portSuspendTurns: UInt64 = 100
}

extension World {
    /// The port rule, after the threshold rules and before the script.
    /// Returns true when it takes the turn: it places the port, or waits
    /// for money or a shore spot. After `RivalAI.waitLimit`
    /// waiting turns it is suspended for `RivalAI.portSuspendTurns`
    /// turns, so the script keeps running. It never moves the script.
    mutating func takeRivalPortTurn(
        _ index: Int,
        houses: Int,
        hasPort: Bool,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> Bool {
        let rival = rivals[index]
        guard !hasPort, houses >= RivalAI.portMinHouses, tickCount >= rival.ai.portRetryTick,
              let center = buildings[rival.townCenterID]
        else { return false }
        let anchor = rival.treasury >= BuildingCatalog.spec(for: .port).cost + RivalAI.safetyMargin
            ? rivalPortAnchor(for: rival, around: center.anchor, tileToIsland: tileToIsland)
            : nil
        var ai = rival.ai
        if let anchor {
            pendingCommands.append(.rivalPlace(rival.id, .port, at: anchor))
            ai.portWaitTurns = 0
        } else {
            ai.portWaitTurns += 1
            if ai.portWaitTurns >= RivalAI.waitLimit {
                ai.portWaitTurns = 0
                ai.portRetryTick = tickCount + RivalAI.portSuspendTurns * difficulty.rivalTurnTicks
            }
        }
        rivals[index].ai = ai
        return true
    }

    /// The first anchor where the rival may place a port (`canPlace`; a
    /// rival's port costs no materials), ring by ring around `center`,
    /// each ring row-major. Visits each anchor within
    /// `RivalAI.portSearchRadius` at most once.
    func rivalPortAnchor(
        for rival: RivalTown,
        around center: TileCoordinate,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> TileCoordinate? {
        for ring in 0 ... RivalAI.portSearchRadius {
            for dy in -ring ... ring {
                // Inside rows only touch the ring at both ends.
                let step = abs(dy) == ring ? 1 : 2 * ring
                for dx in stride(from: -ring, through: ring, by: step) {
                    let anchor = TileCoordinate(x: center.x + dx, y: center.y + dy)
                    if siteRejection(.port, at: anchor, for: rival.owner, tileToIsland: tileToIsland) == nil {
                        return anchor
                    }
                }
            }
        }
        return nil
    }
}
