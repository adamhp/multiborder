import XCTest

/// Drives the app for the App Store media in scripts/demo-videos: `testStoryboard` plays the preview at a
/// watchable pace while `simctl io recordVideo` records, and `testScreenshots` saves the App Store
/// screenshots as attachments. Skipped in normal test runs: the DemoRecording and AppStoreScreenshots
/// schemes set DEMO_RECORDING=1 and run one test each, after `simctl addmedia` has loaded sample-photos/.
nonisolated final class DemoRecordingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["DEMO_RECORDING"] == "1",
                          "Run the DemoRecording scheme to record the demo storyboard")
    }

    @MainActor func testStoryboard() throws {
        let app = launchCleanApp()

        // 0–4s: select several photos at once.
        selectPhotos(in: app, pause: 0.4)
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

    /// The ten App Store screenshots, each saved as an attachment named "NN-name" for render.sh to
    /// export and frame. Screen 9, editing inside the Photos app, comes last because the extension
    /// opens with the settings the earlier screens set.
    @MainActor func testScreenshots() throws {
        let app = launchCleanApp()

        selectPhotos(in: app, pause: 0.2)
        hold(0.8)
        snapshot("01-select")
        app.buttons["Done"].tap()
        hold(1)

        app.buttons["Edit"].tap()
        hold(1)
        drag(app.sliders["Border Width"], to: 0.4)
        hold(0.8)
        snapshot("02-size")

        app.buttons["Rounded Corners"].tap()
        drag(app.sliders["Corner Radius"], to: 0.45)
        app.buttons["Shadow"].tap()
        drag(app.sliders["Shadow"], to: 0.7)
        hold(0.8)
        snapshot("03-corners-shadow")
        // Only screen 3 is about corners and shadows; the rest show plain square photos.
        app.buttons["Rounded Corners"].tap()
        app.buttons["Shadow"].tap()
        hold(0.6)

        app.buttons["Separate Border for Each Side"].tap()
        hold(0.6)
        drag(app.sliders["Bottom Border"], to: 0.75)
        hold(0.8)
        snapshot("04-per-side")
        app.buttons["Separate Border for Each Side"].tap()

        app.buttons["Blurred Photo Border"].tap()
        hold(1.2)
        snapshot("05-blur")
        app.buttons["Blurred Photo Border"].tap()

        app.buttons["Camera Settings Caption"].tap()
        hold(1.2)
        snapshot("06-caption")

        app.buttons["Caption Style"].tap()
        XCTAssertTrue(app.buttons["DM Mono"].waitForExistence(timeout: 5))
        hold(0.8)
        snapshot("07-caption-style")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        hold(0.6)

        app.buttons["Settings"].tap()
        hold(0.8)
        for setting in ["Save to album", "Keep original date"] {
            let toggle = app.switches[setting]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Missing \(setting) switch")
            if toggle.value as? String != "1" { toggle.switches.firstMatch.tap() }
        }
        hold(1.2)
        snapshot("08-settings")

        app.buttons["Export"].tap()
        let download = app.buttons["Download"]
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()
        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 30), "Download never finished")
        hold(0.3)
        snapshot("10-saved")

        snapshotPhotosExtension()
    }

    /// Opens a sample photo in the Photos app and edits it with the Multiborder extension
    /// (Edit → More → Extensions → multiborder).
    @MainActor private func snapshotPhotosExtension() {
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        photos.launch()
        // Photos asks about notifications on its first launch.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let dontAllow = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Don'")).firstMatch
        if dontAllow.waitForExistence(timeout: 3) { dontAllow.tap() }
        // On a fresh Simulator, Photos opens with a "What's New in Photos" sheet.
        let welcome = photos.buttons["Continue"]
        if welcome.waitForExistence(timeout: 3) { welcome.tap() }
        // The label's time uses a narrow no-break space before AM, so match its start.
        let photo = photos.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo, September 30, 2025, 9:41"))
            .firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "Sample photo missing from Photos")
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let edit = photos.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        hold(4)
        // A one-time keyboard tip can cover the bottom of the editor.
        let continueButton = photos.buttons["Continue"]
        if continueButton.exists { continueButton.tap() }
        photos.buttons["More"].tap()
        photos.buttons["Extensions"].tap()
        // The extension shows as a cell in Photos' Extensions sheet.
        let item = photos.descendants(matching: .any)
            .matching(NSPredicate(format: "label ==[c] 'multiborder' AND (elementType == %d OR elementType == %d)",
                                  XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.button.rawValue))
            .firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "Multiborder missing from Extensions")
        item.tap()
        hold(6)
        snapshot("09-photos")
    }

    /// Launches into a clean demo state, closes the picker's one-time "Private Access to Photos"
    /// banner and waits for the sample photos.
    @MainActor private func launchCleanApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoRecording"]
        app.launch()
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 5) { close.tap() }
        let photos = app.images.matching(identifier: "PXGGridLayout-Info")
        XCTAssertTrue(photos.element(boundBy: 3).waitForExistence(timeout: 10), "Run simctl addmedia first")
        hold(1)
        return app
    }

    /// Selects the four newest photos (the samples). The picker runs out of process, so its photos never
    /// report as hittable: tap the ones fully between its top bar and bottom toolbar by position.
    @MainActor private func selectPhotos(in app: XCUIApplication, pause: TimeInterval) {
        let photos = app.images.matching(identifier: "PXGGridLayout-Info")
        let topBar = app.navigationBars["Photos"].frame.maxY
        let toolbar = app.buttons["Sort and Filter"].frame.minY
        let visible = photos.allElementsBoundByIndex
            .filter { $0.frame.minY >= topBar && $0.frame.maxY <= toolbar }
            .prefix(4)
        XCTAssertEqual(visible.count, 4, "Fewer than 4 photos on screen")
        for photo in visible {
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            hold(pause)
        }
    }

    /// Saves the whole screen, at device resolution, as an attachment that outlives the test run.
    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
