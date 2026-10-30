import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Distant-house market hint (openspec/changes/visible-distribution).

private let title = "Your town is outgrowing its market"

/// A session on the market strip with a player house `distance` road tiles
/// from the town center and the first-hour guide hidden.
@MainActor
private func session(houseAt distance: Int, owner: Owner = .player) -> GameSession {
    var (world, _) = marketStrip()
    placeOperational(.house, at: TileCoordinate(x: distance + 2, y: 4), residents: 2, owner: owner, in: &world)
    let session = GameSession(world: world)
    session.hideFirstSteps()
    return session
}

@MainActor
@Test("scenario: A house near the edge of the reach raises the hint")
func houseNearTheEdgeRaisesTheHint() {
    let session = session(houseAt: 15)
    session.step()
    #expect(session.banner?.title == title)
    #expect(session.banner?.description
        == "Porters carry goods only 18 road tiles from the town center or a marketplace. Build a marketplace near your outer houses.")
    for _ in 0 ..< Int(GameSession.bannerTicks) + 5 {
        session.step()
    }
    #expect(session.banner == nil)
    for _ in 0 ..< 200 {
        session.step()
    }
    #expect(session.banner?.title != title)
}

@MainActor
@Test("scenario: Houses close to the market raise no hint")
func housesCloseToTheMarketRaiseNoHint() {
    let session = session(houseAt: 10)
    for _ in 0 ..< 5 {
        session.step()
    }
    #expect(!session.hintedDistantHouses)
}

@MainActor
@Test("scenario: A rival's distant house raises no hint")
func rivalsDistantHouseRaisesNoHint() {
    let session = session(houseAt: 15, owner: .rival(1))
    session.step()
    #expect(!session.hintedDistantHouses)
}

@MainActor
@Test("a house out of every market's reach raises the hint and stops the problem hint naming it")
func houseOutOfReachRaisesTheHintInsteadOfTheProblem() {
    let session = session(houseAt: 38)
    session.step()
    #expect(session.banner?.title == title)
    #expect(session.hintedProblems.contains(InspectorViewModel.problemText(.noMarketInReach)))
}

@MainActor
@Test("a hint raised only by a house near the edge leaves a later out-of-reach house to the problem hint")
func nearEdgeHintLeavesTheOutOfReachProblemHint() {
    let session = session(houseAt: 15)
    session.step()
    #expect(session.banner?.title == title)
    #expect(!session.hintedProblems.contains(InspectorViewModel.problemText(.noMarketInReach)))
    placeOperational(.house, at: TileCoordinate(x: 40, y: 4), residents: 2, in: &session.world)
    var named = false
    for _ in 0 ..< Int(GameSession.bannerTicks + GameSession.problemHintDelayTicks) + 50 where !named {
        session.step()
        named = session.banner?.description.hasPrefix("No market in reach") == true
    }
    #expect(named)
}
