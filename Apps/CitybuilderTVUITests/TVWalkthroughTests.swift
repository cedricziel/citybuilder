import XCTest

/// Drives the Apple TV app with the simulator's Siri Remote and saves a
/// screenshot at each step. Screenshots go to `WALKTHROUGH_DIR` when it is
/// set (pass `TEST_RUNNER_WALKTHROUGH_DIR=<dir>` to xcodebuild), and are
/// always attached to the test result. Used for the focus walk-throughs in
/// the verify skill.
@MainActor
final class TVWalkthroughTests: XCTestCase {
    let remote = XCUIRemote.shared
    let app = XCUIApplication()

    func testTitleScreenFocusesNewGameFirst() {
        launch()
        snapshot("title")
        XCTAssertTrue(app.buttons["title.newGame"].hasFocus, "New Game should hold the initial focus")
    }

    func testNewGameDialogFocusesStartAndBackCancels() {
        launch()
        remote.press(.select)
        XCTAssertTrue(app.buttons["newGame.start"].waitForExistence(timeout: 5))
        snapshot("new-game")
        XCTAssertTrue(app.buttons["newGame.start"].hasFocus, "Start should hold the initial focus")
        remote.press(.menu)
        XCTAssertTrue(app.buttons["title.newGame"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntilGone(app.buttons["newGame.start"]), "Back should close New Game")
    }

    func testTitleSettingsOpenAndBackCloses() {
        launch()
        let settings = app.buttons["title.settings"]
        focus(settings)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Audio"].waitForExistence(timeout: 5), "Settings did not open")
        snapshot("title-settings")
        let credits = app.buttons["Credits"]
        focus(credits)
        remote.press(.select)
        XCTAssertTrue(
            app.staticTexts["Audio assets used in this app:"].waitForExistence(timeout: 5),
            "Credits did not show"
        )
        snapshot("title-settings-credits")
        goBack(to: settings, name: "Settings")
    }

    func testScenarioShowsGoalsPanel() {
        startGame {
            // Start, Cancel, Sandbox, then Scenario: a segment is selected
            // as focus lands on it.
            for direction in [XCUIRemote.Button.left, .down, .right] {
                self.remote.press(direction)
            }
            self.snapshot("new-game-scenario")
            XCTAssertTrue(self.app.buttons["Scenario"].isSelected, "Scenario should be selected")
        }
        snapshot("in-game-scenario")
        openAndGoBack(app.buttons["Goals"], expecting: app.buttons["Done"].firstMatch, snapshot: "panel-goals")
    }

    func testRivalTownsShowStandingsPanel() {
        startGame { self.choose(self.app.buttons["Archipelago"]) }
        openAndGoBack(app.buttons["Standings"], expecting: app.buttons["Done"].firstMatch, snapshot: "panel-standings")
    }

    func testInGamePanelsOpenAndBackCloses() {
        startGame()
        snapshot("in-game")
        XCTAssertTrue(app.buttons["Town"].exists, "the build rail should show")
        XCTAssertFalse(app.buttons["title.newGame"].exists, "the title screen should be gone")
        openAndGoBack(app.buttons["Research"], expecting: app.buttons["Done"].firstMatch, snapshot: "panel-research")
        openAndGoBack(app.buttons["Settings"], expecting: app.buttons["Audio"].firstMatch, snapshot: "panel-settings")
    }

    func testPauseMenuSettingsBackReturnsToMenu() {
        startGame()
        let pause = app.buttons["Pause"]
        focus(pause)
        remote.press(.select)
        let resume = app.buttons["pause.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertTrue(resume.hasFocus, "Resume should hold the initial focus")
        let settings = app.buttons["pause.settings"]
        focus(settings)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Audio"].waitForExistence(timeout: 5), "pause Settings did not open")
        XCTAssertFalse(app.buttons["Pause"].exists, "the game should stay paused under Settings")
        snapshot("pause-settings")
        goBack(to: settings, name: "pause Settings")
        snapshot("pause-after-settings")
        goBack(to: pause, name: "pause menu")
    }

    func testSavedGameContinuesFromTheTitle() {
        startGame()
        focus(app.buttons["Pause"])
        remote.press(.select)
        let save = app.buttons["pause.saveGame"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        choose(save)
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 5), "Save Game did not report Saved")
        app.terminate()

        app.launchArguments = []
        app.launch()
        let continueGame = app.buttons["title.continue"]
        XCTAssertTrue(continueGame.waitForExistence(timeout: 10))
        waitForFocus(continueGame)
        snapshot("title-continue")
        remote.press(.select)
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10), "Continue should open the saved game")
    }

    func testMapHoldsFocusAndClicksMoveTheReticle() {
        startGame(inHUD: false)
        let reticle = app.descendants(matching: .any)["tv.reticle"]
        XCTAssertTrue(reticle.waitForExistence(timeout: 5), "the reticle should show while the map has focus")
        let before = reticle.label
        remote.press(.right)
        let moved = NSPredicate(format: "label != %@", before)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation(for: moved, evaluatedWith: reticle)], timeout: 5),
            .completed,
            "a click should step the reticle"
        )
        XCTAssertTrue(app.descendants(matching: .any)["tv.map"].hasFocus, "a click on the map must not move focus")
        snapshot("map-reticle")
    }

    func testBackOnTheMapOpensThePauseMenu() {
        startGame(inHUD: false)
        remote.press(.menu)
        XCTAssertTrue(app.buttons["pause.resume"].waitForExistence(timeout: 5), "Back on an idle map should pause")
        snapshot("map-back-pause")
        remote.press(.menu)
        XCTAssertTrue(waitUntilGone(app.buttons["pause.resume"]), "Back on the pause menu should resume")
        XCTAssertTrue(app.descendants(matching: .any)["tv.reticle"].waitForExistence(timeout: 5), "the map should have focus again")
    }

    func testPlayPauseMovesFocusBetweenMapAndHUD() {
        startGame(inHUD: false)
        remote.press(.playPause)
        waitForFocus(app.buttons["Town"])
        XCTAssertTrue(waitUntilGone(app.descendants(matching: .any)["tv.reticle"]), "the reticle hides while the HUD has focus")
        remote.press(.playPause)
        XCTAssertTrue(app.descendants(matching: .any)["tv.reticle"].waitForExistence(timeout: 5), "Play/Pause should return to the map")
    }

    func testChoosingAHouseStartsPlacementOnTheMap() {
        startGame()
        remote.press(.select)
        let house = app.buttons["House"].firstMatch
        XCTAssertTrue(house.waitForExistence(timeout: 5), "the Town drawer should open")
        focus(house)
        remote.press(.select)
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        let hint = app.staticTexts["Move, then click to place house. Back to cancel."]
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "the tool strip should show the Apple TV placement hint")
        snapshot("map-placing-house")
        remote.press(.menu)
        XCTAssertTrue(waitUntilGone(hint), "Back should cancel the placement")
    }

    func testZoomButtonsInTheTopBar() {
        startGame()
        let zoomIn = app.buttons["Zoom In"]
        XCTAssertTrue(zoomIn.exists, "the top bar should offer zoom on Apple TV")
        focus(zoomIn)
        remote.press(.select)
        snapshot("zoomed-in")
        XCTAssertTrue(app.buttons["Zoom Out"].exists)
    }

    func testBackFromADrawerClosesItThenReturnsToTheMap() {
        startGame()
        remote.press(.select)
        let house = app.buttons["House"].firstMatch
        XCTAssertTrue(house.waitForExistence(timeout: 5), "the Town drawer should open")
        // Let the drawer finish opening; a Back mid-animation can be lost.
        Thread.sleep(forTimeInterval: 1)
        snapshot("drawer-open")
        remote.press(.menu)
        let closed = waitUntilGone(house)
        snapshot("drawer-after-back")
        XCTAssertTrue(closed, "Back should close the drawer")
        XCTAssertFalse(app.descendants(matching: .any)["tv.map"].hasFocus, "the first Back only closes the drawer")
        remote.press(.menu)
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        XCTAssertFalse(app.buttons["pause.resume"].exists, "Back from the HUD returns to the map without pausing")
    }

    func testBackFromTheInspectorReturnsToTheMap() {
        startGame(inHUD: false)
        let callout = app.descendants(matching: .any)["inspector.callout"]
        for step in [XCUIRemote.Button.left, .up, .up] where !callout.exists {
            remote.press(.select)
            if callout.waitForExistence(timeout: 2) { break }
            remote.press(step)
        }
        XCTAssertTrue(callout.exists, "selecting the town center should show its callout")
        remote.press(.select)
        snapshot("inspector-focused")
        let focusedInCallout = callout.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        XCTAssertTrue(focusedInCallout.waitForExistence(timeout: 5), "select on the selected building focuses its callout")
        remote.press(.menu)
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        XCTAssertFalse(app.buttons["pause.resume"].exists, "Back from the callout returns to the map")
    }

    /// Every market row takes focus, even one whose buttons are all off,
    /// so the remote can scroll the whole list into view; Less stays on
    /// screen throughout.
    func testTownCenterMarketRowsTakeFocus() {
        startGame(inHUD: false)
        let callout = app.descendants(matching: .any)["inspector.callout"]
        for step in [XCUIRemote.Button.left, .up, .up] where !callout.exists {
            remote.press(.select)
            if callout.waitForExistence(timeout: 2) { break }
            remote.press(step)
        }
        XCTAssertTrue(callout.exists, "selecting the town center should show its callout")
        remote.press(.select)
        let details = app.buttons["Details"]
        focus(details)
        remote.press(.select)
        let less = app.buttons["Less"]
        XCTAssertTrue(less.waitForExistence(timeout: 5), "Details should open")
        XCTAssertTrue(app.buttons["Buy 1"].firstMatch.waitForExistence(timeout: 5), "the market should show")
        snapshot("market-open")
        let rows = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'sell $'"))
        let first = rows.element(boundBy: 0)
        let last = rows.element(boundBy: rows.count - 1)
        press(.up, until: first)
        snapshot("market-first-row")
        press(.down, until: last)
        XCTAssertTrue(less.isHittable, "Less should stay on screen")
        snapshot("market-last-row")
        let otherGoods = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Other goods'")).firstMatch
        XCTAssertTrue(otherGoods.exists, "goods the island cannot use should collapse under Other goods")
        press(.down, until: otherGoods)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Hide other goods"].waitForExistence(timeout: 5), "Other goods should expand")
        snapshot("market-other-goods")
    }

    /// Presses `direction` until `element` holds focus, at most 60 times.
    private func press(_ direction: XCUIRemote.Button, until element: XCUIElement) {
        var presses = 0
        while !element.hasFocus, presses < 60 {
            remote.press(direction)
            presses += 1
        }
        XCTAssertTrue(element.hasFocus, "\(element.label) should take focus")
    }

    func testPlayPauseInTheHUDReturnsToTheMapOnce() {
        startGame()
        remote.press(.playPause)
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        snapshot("map-after-hud-playpause")
    }

    func testRoutesAndTheManifestEditorWithTheRemote() {
        startGame(seed: ["-uiTestSeedPort"])
        let routes = app.buttons["Routes"]
        XCTAssertTrue(routes.waitForExistence(timeout: 5), "a player port should show the Routes button")
        openAndGoBack(routes, expecting: app.buttons["New Route"].firstMatch, snapshot: "panel-routes")

        focus(routes)
        remote.press(.select)
        let newRoute = app.buttons["New Route"].firstMatch
        XCTAssertTrue(newRoute.waitForExistence(timeout: 5))
        snapshot("routes-new-route-focus")
        remote.press(.select)
        let commit = app.buttons["Commit"]
        XCTAssertTrue(commit.waitForExistence(timeout: 5), "New Route should start route mode")

        // The seed puts the reticle on the port: Play/Pause to the map,
        // select adds it as the first stop.
        remote.press(.playPause)
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        remote.press(.select)
        let stop = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1. '")).firstMatch
        XCTAssertTrue(stop.waitForExistence(timeout: 5), "select on the port should add it as a stop")
        snapshot("route-mode-stop")
        let stopChip = app.buttons[stop.label]

        remote.press(.playPause)
        focus(stop)
        remote.press(.select)
        let manifestDone = app.buttons["Done"].firstMatch
        XCTAssertTrue(manifestDone.waitForExistence(timeout: 5), "the stop should open the manifest editor")
        snapshot("manifest-editor")
        goBack(to: stop, name: "manifest editor")

        // Back on the map removes the stop, then leaves route mode.
        remote.press(.playPause)
        waitForFocus(app.descendants(matching: .any)["tv.map"])
        remote.press(.menu)
        let removed = waitUntilGone(stopChip)
        snapshot("route-mode-after-back")
        XCTAssertTrue(removed, "Back in route mode should remove the last stop")
        remote.press(.menu)
        XCTAssertTrue(waitUntilGone(commit), "Back with no stops should leave route mode")
        XCTAssertFalse(app.buttons["pause.resume"].exists, "leaving route mode must not pause")
    }
}
