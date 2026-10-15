import XCTest

/// Launch, focus and screenshot helpers for the walk-throughs.
extension TVWalkthroughTests {
    /// Launches with an empty save folder, so New Game is the primary
    /// button.
    func launch(seed: [String] = []) {
        continueAfterFailure = true
        app.launchArguments = ["-uiTestResetSaves"] + seed
        app.launch()
        let newGame = app.buttons["title.newGame"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10))
        waitForFocus(newGame)
    }

    /// The title's buttons enable, and take focus, once the iCloud check
    /// ends.
    func waitForFocus(_ element: XCUIElement) {
        wait(for: [expectation(for: NSPredicate(format: "hasFocus == true"), evaluatedWith: element)], timeout: 20)
    }

    /// Starts a game from New Game; `configure` runs with the dialog open.
    /// The map has focus once the game starts; with `inHUD`, Play/Pause
    /// then moves focus to the build rail.
    func startGame(inHUD: Bool = true, seed: [String] = [], configure: () -> Void = {}) {
        launch(seed: seed)
        remote.press(.select)
        let start = app.buttons["newGame.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        waitForFocus(start)
        configure()
        focus(start)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 10))
        if inHUD {
            remote.press(.playPause)
            waitForFocus(app.buttons["Town"])
        }
    }

    /// Opens the screen behind `button`, checks that `content` shows,
    /// and that one Back returns to `button`.
    func openAndGoBack(_ button: XCUIElement, expecting content: XCUIElement, snapshot name: String) {
        XCTAssertTrue(button.exists, "\(button.label) button missing")
        focus(button)
        remote.press(.select)
        XCTAssertTrue(content.waitForExistence(timeout: 5), "\(name) did not open")
        snapshot(name)
        goBack(to: button, name: name)
    }

    /// Presses Back until `button` is hittable again, and fails when that
    /// takes more than one press.
    func goBack(to button: XCUIElement, name: String) {
        remote.press(.menu)
        if waitUntil(button, isHittable: true) { return }
        remote.press(.menu)
        XCTAssertTrue(waitUntil(button, isHittable: true), "Back twice did not close \(name)")
        XCTFail("\(name) needed two Back presses")
    }

    /// Selects `element`. A segment of a segmented picker is selected as
    /// soon as focus passes over it, without a press.
    func choose(_ element: XCUIElement) {
        focus(element, stopWhenSelected: true)
        if !element.isSelected {
            remote.press(.select)
        }
    }

    /// Presses toward `element` from whatever has focus until it does.
    /// When a press along the main axis brings focus no closer, as at the
    /// edge of a focus section or between two buttons in a row, the next
    /// press tries the other axis.
    func focus(_ element: XCUIElement, stopWhenSelected: Bool = false) {
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

    func waitUntil(_ element: XCUIElement, isHittable: Bool) -> Bool {
        let predicate = NSPredicate(format: "isHittable == %@", NSNumber(value: isHittable))
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    func waitUntilGone(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    func snapshot(_ name: String) {
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
