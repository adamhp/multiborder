//
//  multiborderUITests.swift
//  multiborderUITests
//
//  Created by Adam Pearce on 6/14/24.
//

import XCTest

// XCTestCase overrides are nonisolated, so opt out of the target's default MainActor isolation.
nonisolated final class multiborderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testLaunchShowsTabBar() throws {
        let app = XCUIApplication()
        app.launch()
        for title in ["Select", "Edit", "Export"] {
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5), "Missing \(title) tab")
        }
    }

    /// -demoRecording wins over -resetFeatureIntro, so demo takes never show What's New.
    @MainActor func testDemoRecordingLaunchIsClean() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetFeatureIntro", "-demoRecording"]
        app.launch()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5), "Missing Select tab")
        XCTAssertFalse(app.staticTexts["What’s New"].waitForExistence(timeout: 2), "What's New showed during a demo launch")
    }

    @MainActor func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
