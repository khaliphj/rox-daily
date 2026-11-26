import XCTest

/// Walks the main flows of the app end to end on a fresh install.
final class RoxDailyUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    private func reveal(_ element: XCUIElement, swipes: Int = 12) {
        var n = 0
        while !(element.exists && element.isHittable) && n < swipes {
            app.swipeUp()
            n += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing: \(element)")
    }

    func testFullFlow() {
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // Onboarding
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.staticTexts["Set up your plan"].waitForExistence(timeout: 5))
        let build = app.buttons["Build my plan"]
        reveal(build)
        build.tap()

        // Today
        XCTAssertTrue(app.staticTexts["Today's session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'days to HYROX Atlanta'")).firstMatch.exists)

        // Plan: open a strength session, tick a row, complete it
        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.staticTexts["Week 1"].waitForExistence(timeout: 5))
        app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Strength: '")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Why this session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Warm-up"].exists)
        // Stopwatch: runs, pauses and resets
        let start = app.buttons["Start stopwatch"]
        reveal(start)
        let clock = app.staticTexts["stopwatch"]
        XCTAssertEqual(clock.label, "0:00")
        start.tap()
        sleep(3)
        app.buttons["Pause stopwatch"].tap()
        let paused = clock.label
        XCTAssertNotEqual(paused, "0:00", "Stopwatch should have advanced")
        sleep(2)
        XCTAssertEqual(clock.label, paused, "Stopwatch should hold while paused")
        app.buttons["Reset stopwatch"].tap()
        XCTAssertEqual(clock.label, "0:00")

        let complete = app.buttons["Mark complete"]
        reveal(complete)
        complete.tap()
        XCTAssertTrue(app.navigationBars["Log session"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Completed · tap to undo"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1/5"].waitForExistence(timeout: 5), "Week 1 should show one of five sessions done")

        // For Time library
        app.buttons["For Time"].tap()
        app.staticTexts["Quarter Race"].tap()
        XCTAssertTrue(app.staticTexts["QUARTER RACE"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // News: every topic renders, and the live feed returns stories
        app.tabBars.buttons["News"].tap()
        XCTAssertTrue(app.staticTexts["Latest in Atlanta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Race finder and tickets"].exists)
        app.buttons["All News"].tap()
        XCTAssertTrue(app.staticTexts["Latest"].waitForExistence(timeout: 5))
        let story = app.images["arrow.up.right"].firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 30), "Live news feed returned no stories")

        // Race: pacing card and a station guide
        app.tabBars.buttons["Race"].tap()
        XCTAssertTrue(app.staticTexts["Each 1 km run"].waitForExistence(timeout: 5))
        let wallBalls = app.staticTexts["100 reps · 6 kg (13 lb) to 3.00 m (about 10 ft)"]
        reveal(wallBalls)
        wallBalls.tap()
        XCTAssertTrue(app.staticTexts["Technique"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        // Progress: add a benchmark
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Streak"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Add result"].waitForExistence(timeout: 5))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["25:00"].waitForExistence(timeout: 5))

        // Settings: change training days, plan rebuilds
        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let fewer = app.steppers.firstMatch.buttons["Decrement"]
        reveal(fewer)
        fewer.tap()
        XCTAssertTrue(app.staticTexts["Training days per week: 4"].waitForExistence(timeout: 5))

        // Daily reminder: switch on, allow notifications, confirm iOS has it scheduled
        let reminder = app.switches["Daily reminder"]
        reveal(reminder)
        reminder.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
        if allow.waitForExistence(timeout: 8) { allow.tap() }
        let scheduled = app.staticTexts["Scheduled daily at 7:00"]
        var tries = 0
        while !scheduled.exists && tries < 4 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(scheduled.waitForExistence(timeout: 8), "iOS should hold a pending daily reminder")

        app.buttons["Save"].tap()
        app.tabBars.buttons["Plan"].tap()
        // The Plan tab was left on its For Time segment; switch back to the weeks.
        app.scrollViews.buttons["Plan"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1/4"].waitForExistence(timeout: 5), "Plan should rebuild to four sessions a week")

        // Persistence across relaunch
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["Today's session"].waitForExistence(timeout: 8), "Profile should persist")
    }
}
