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
        openAndGoBack(app.buttons["title.settings"], snapshot: "title-settings")
    }

    private func launch() {
        continueAfterFailure = true
        app.launch()
        let newGame = app.buttons["title.newGame"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10))
        // New Game enables, and takes focus, once the iCloud check ends.
        wait(for: [expectation(for: NSPredicate(format: "hasFocus == true"), evaluatedWith: newGame)], timeout: 10)
    }

    /// Opens the screen behind `button`, snapshots it, and checks that Back
    /// returns to `button`.
    private func openAndGoBack(_ button: XCUIElement, snapshot name: String) {
        XCTAssertTrue(button.exists, "\(button.label) button missing")
        focus(button)
        remote.press(.select)
        XCTAssertTrue(waitUntil(button, isHittable: false), "\(name) did not open")
        snapshot(name)
        remote.press(.menu)
        XCTAssertTrue(waitUntil(button, isHittable: true), "Back should close \(name)")
    }

    /// Presses toward `element` from whatever has focus until it does.
    private func focus(_ element: XCUIElement) {
        let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
        let target = element.frame
        var presses = 0
        while !element.hasFocus, presses < 40 {
            presses += 1
            guard focused.exists else {
                remote.press(.down)
                continue
            }
            let from = focused.frame
            let dx = target.midX - from.midX
            let dy = target.midY - from.midY
            if abs(dx) > abs(dy) {
                remote.press(dx > 0 ? .right : .left)
            } else {
                remote.press(dy > 0 ? .down : .up)
            }
        }
        XCTAssertTrue(element.hasFocus, "could not focus \(element.identifier) \(element.label)")
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
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
