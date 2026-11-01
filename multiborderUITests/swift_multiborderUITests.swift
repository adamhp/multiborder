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

    @MainActor func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
