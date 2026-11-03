import XCTest

/// Plays the App Store preview storyboard at a watchable pace while `simctl io recordVideo` records
/// the screen (see scripts/demo-videos). Skipped in normal test runs: the DemoRecording scheme
/// sets DEMO_RECORDING=1 and runs only this test, after `simctl addmedia` has loaded sample-photos/.
nonisolated final class DemoRecordingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEMO_RECORDING"] == "1",
                          "Run the DemoRecording scheme to record the demo storyboard")
    }

    @MainActor func testStoryboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRecording"]
        app.launch()

        // The picker's one-time "Private Access to Photos" banner isn't part of the story.
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 5) { close.tap() }

        let photos = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(photos.element(boundBy: 3).waitForExistence(timeout: 10), "Run simctl addmedia first")
        hold(1)

        // 0–4s: select several photos at once.
        // The newest photos (the samples) come first. The picker runs out of process, so its photos never
        // report as hittable: tap the ones fully between its top bar and bottom toolbar by position.
        let topBar = app.navigationBars["Photos"].frame.maxY
        let toolbar = app.buttons["Sort and Filter"].frame.minY
        let visible = photos.allElementsBoundByIndex
            .filter { $0.frame.minY >= topBar && $0.frame.maxY <= toolbar }
            .prefix(4)
        XCTAssertEqual(visible.count, 4, "Fewer than 4 photos on screen")
        for photo in visible {
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            hold(0.4)
        }
        app.buttons["Done"].tap()
        hold(1.5)

        // 4–10s: size and aspect ratio, every photo updating together.
        app.buttons["Edit"].tap()
        hold(1)
        drag(app.sliders["Border Width"], to: 0.4)
        hold(0.6)
        // 4:5 is the default, so square the photos up.
        app.buttons["Aspect Ratio 1:1"].tap()
        hold(1)

        // 10–16s: rounded corners and a shadow.
        app.buttons["Rounded Corners"].tap()
        hold(0.6)
        drag(app.sliders["Corner Radius"], to: 0.45)
        hold(0.4)
        app.buttons["Shadow"].tap()
        hold(0.6)
        drag(app.sliders["Shadow"], to: 0.7)
        hold(1)

        // 16–21s: the camera settings caption, then a different font.
        app.buttons["Camera Settings Caption"].tap()
        hold(1.5)
        app.buttons["Caption Style"].tap()
        let font = app.buttons["DM Mono"]
        XCTAssertTrue(font.waitForExistence(timeout: 5))
        hold(0.6)
        font.tap()
        hold(0.8)
        // Dismiss the popover by tapping above it, on the preview.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        hold(1.2)

        // 21–25s: download and end on the app's own saved state.
        app.buttons["Export"].tap()
        hold(1)
        let download = app.buttons["Download"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 30), "Download never finished")
        hold(2)
    }

    /// Waits without touching the app, so the recording shows each state long enough to read.
    @MainActor private func hold(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Drags a slider's thumb slowly enough to see it move. The drag starts on the thumb, since
    /// pressing elsewhere on the track doesn't move it.
    @MainActor private func drag(_ slider: XCUIElement, to end: CGFloat) {
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "Missing slider \(slider)")
        let start = min(max(slider.normalizedSliderPosition, 0.03), 0.97)
        let from = slider.coordinate(withNormalizedOffset: CGVector(dx: start, dy: 0.5))
        let to = slider.coordinate(withNormalizedOffset: CGVector(dx: end, dy: 0.5))
        from.press(forDuration: 0.15, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertGreaterThan(abs(slider.normalizedSliderPosition - start), 0.1, "\(slider) didn't move")
    }
}
