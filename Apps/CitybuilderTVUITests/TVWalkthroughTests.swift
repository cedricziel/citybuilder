import XCTest

/// Drives the Apple TV app with the simulator's Siri Remote and saves a
/// screenshot at each step. Screenshots go to `WALKTHROUGH_DIR` when it is
/// set (pass `TEST_RUNNER_WALKTHROUGH_DIR=<dir>` to xcodebuild), and are
/// always attached to the test result. Used for the focus walk-throughs in
/// the verify skill.
@MainActor
final class TVWalkthroughTests: XCTestCase {
    private let remote = XCUIRemote.shared
    private let app = XCUIApplication()

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

    /// Launches with an empty save folder, so New Game is the primary
    /// button.
    private func launch() {
        continueAfterFailure = true
        app.launchArguments = ["-uiTestResetSaves"]
        app.launch()
        let newGame = app.buttons["title.newGame"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10))
        waitForFocus(newGame)
    }

    /// The title's buttons enable, and take focus, once the iCloud check
    /// ends.
    private func waitForFocus(_ element: XCUIElement) {
        wait(for: [expectation(for: NSPredicate(format: "hasFocus == true"), evaluatedWith: element)], timeout: 20)
    }

    /// Starts a game from New Game; `configure` runs with the dialog open.
    private func startGame(configure: () -> Void = {}) {
        launch()
        remote.press(.select)
        let start = app.buttons["newGame.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        waitForFocus(start)
        configure()
        focus(start)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
    }

    /// Opens the screen behind `button`, checks that `content` shows,
    /// and that one Back returns to `button`.
    private func openAndGoBack(_ button: XCUIElement, expecting content: XCUIElement, snapshot name: String) {
        XCTAssertTrue(button.exists, "\(button.label) button missing")
        focus(button)
        remote.press(.select)
        XCTAssertTrue(content.waitForExistence(timeout: 5), "\(name) did not open")
        snapshot(name)
        goBack(to: button, name: name)
    }

    /// Presses Back until `button` is hittable again, and fails when that
    /// takes more than one press.
    private func goBack(to button: XCUIElement, name: String) {
        remote.press(.menu)
        if waitUntil(button, isHittable: true) { return }
        remote.press(.menu)
        XCTAssertTrue(waitUntil(button, isHittable: true), "Back twice did not close \(name)")
        XCTFail("\(name) needed two Back presses")
    }

    /// Selects `element`. A segment of a segmented picker is selected as
    /// soon as focus passes over it, without a press.
    private func choose(_ element: XCUIElement) {
        focus(element, stopWhenSelected: true)
        if !element.isSelected {
            remote.press(.select)
        }
    }

    /// Presses toward `element` from whatever has focus until it does.
    /// When a press along the main axis brings focus no closer, as at the
    /// edge of a focus section or between two buttons in a row, the next
    /// press tries the other axis.
    private func focus(_ element: XCUIElement, stopWhenSelected: Bool = false) {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        let target = element.frame
        func distance(_ frame: CGRect) -> CGFloat {
            hypot(target.midX - frame.midX, target.midY - frame.midY)
        }
        var presses = 0
        var stuck = false
        var last: CGRect? = focused.exists ? focused.frame : nil
        while !element.hasFocus, !(stopWhenSelected && element.isSelected), presses < 40 {
            presses += 1
            guard let from = last else {
                remote.press(.down)
                last = focused.exists ? focused.frame : nil
                continue
            }
            let dx = target.midX - from.midX
            let dy = target.midY - from.midY
            let horizontal = (abs(dx) > abs(dy)) != stuck
            if horizontal, dx != 0 {
                remote.press(dx > 0 ? .right : .left)
            } else {
                remote.press(dy > 0 ? .down : .up)
            }
            let now = focused.exists ? focused.frame : nil
            stuck = now.map { distance($0) >= distance(from) } ?? false
            last = now
        }
        XCTAssertTrue(
            element.hasFocus || (stopWhenSelected && element.isSelected),
            "could not focus \(element.identifier) \(element.label)"
        )
    }

    private func waitUntil(_ element: XCUIElement, isHittable: Bool) -> Bool {
        let predicate = NSPredicate(format: "isHittable == %@", NSNumber(value: isHittable))
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["WALKTHROUGH_DIR"] {
            let folder = URL(fileURLWithPath: dir)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try screenshot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
            } catch {
                XCTFail("could not write \(name).png to \(dir): \(error)")
            }
        }
    }
}
