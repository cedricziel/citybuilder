import XCTest

/// The map overview with the remote. Spec: `platform-shells` / Apple TV map
/// overview.
extension TVWalkthroughTests {
    /// Starts a game and opens the overview from the top bar's Map button.
    private func openOverviewFromTopBar() -> XCUIElement {
        startGame()
        let mapButton = app.buttons["hud.mapOverview"]
        XCTAssertTrue(mapButton.waitForExistence(timeout: 5), "the top bar should offer Map")
        focus(mapButton)
        remote.press(.select)
        let overview = app.descendants(matching: .any)["tv.overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 5), "Map should open the overview")
        return overview
    }

    func testMapOverviewFromTheTopBarJumpsAndCloses() {
        let overview = openOverviewFromTopBar()
        snapshot("map-overview")
        remote.press(.right)
        remote.press(.right)
        snapshot("map-overview-cursor-moved")
        remote.press(.select)
        XCTAssertTrue(waitUntilGone(overview), "select should close the overview")
        snapshot("map-after-overview-jump")
    }

    func testZoomCycleReachesTheOverviewAndBackCloses() {
        startGame(inHUD: false)
        let overview = app.descendants(matching: .any)["tv.overview"]
        for _ in 0 ..< 4 {
            remote.press(.playPause, forDuration: 0.6)
            if overview.waitForExistence(timeout: 2) { break }
        }
        XCTAssertTrue(overview.exists, "the zoom cycle should reach the overview")
        snapshot("map-overview-from-zoom-cycle")
        remote.press(.menu)
        XCTAssertTrue(waitUntilGone(overview), "Back should close the overview")
        XCTAssertFalse(app.buttons["pause.resume"].exists, "closing the overview must not pause")
    }

    func testBackClosesTheOverviewOpenedFromTheTopBar() {
        let overview = openOverviewFromTopBar()
        remote.press(.menu)
        XCTAssertTrue(waitUntilGone(overview), "Back should close the overview")
        XCTAssertEqual(app.state, .runningForeground, "Back must not leave the app")
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        XCTAssertFalse(app.buttons["pause.resume"].exists, "closing the overview must not pause")
    }
}
