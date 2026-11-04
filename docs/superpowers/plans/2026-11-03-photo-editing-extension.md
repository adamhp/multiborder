# Photo Editing Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Photo Editing Extension so a photo can get a multiborder border from Photos' Edit screen, using the app's own Edit page and renderer, with the border's settings saved in the edit so it can be changed later.

**Architecture:** The Edit page's settings move out of `DataModel` into a small `BorderEditor` that can run without saving. The Edit page's files move into a new `EditingUI/` folder compiled by both the app and the new `EditBorderExtension` target, and `EditView` takes its preview as a parameter (the app passes the card stack, the extension passes the one photo). Pure PhotoKit glue (adjustment data, output format, canvas budget) goes in `Shared/` so it's unit-tested from the app's test target.

**Tech Stack:** Swift 6 (default MainActor isolation), SwiftUI, PhotoKit (`PHContentEditingController`, `PHContentEditingOutput`, `PHAdjustmentData`), ImageIO via `ImageComposer`, Swift Testing. Xcode project with synchronized folders, edited by hand like the existing `AB…`/`AC…` targets.

**Spec:** `docs/superpowers/specs/2026-11-03-photo-editing-extension-design.md`

## Global Constraints

- iOS 17.0 deployment target, like every other target; HDR stays iOS 18+ as in `ImageComposer`.
- Extension point `com.apple.photo-editing`, `PHSupportedMediaTypes` = `Image`, principal class `$(PRODUCT_MODULE_NAME).PhotoEditingViewController`.
- App Group `group.com.adamhp.multiborder`: read from the extension, never written.
- Adjustment data: format identifier `com.adamhp.multiborder.border`, version `1`, data = `JSONEncoder` of `BorderSettings`.
- Full size: the render's `exportWidth` is 0, and the extension's canvas budget is the app's 400 MB, not the share sheet's 40 MB.
- The app's Edit page must look and behave exactly as before.
- Other-edits note, exact copy: "This photo has other edits. The border is added on top of them. To change a border added earlier, revert the photo in Photos first."
- Shell: run `xcodebuild`/`xcrun` as one bare command each (no `cd`, pipes, redirects), e.g. tests: `xcodebuild test -quiet -project /Users/adam/dev/multiborder-2.0/multiborder.xcodeproj -scheme multiborder -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:multiborderTests`. Device build/install commands are in the project memory (`xcodebuild-sandbox-exclusion`).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never commit `IMG_1573.HEIC`.

## Review Focus

1. **A rotated photo** (EXIF orientation 6, i.e. any portrait iPhone photo): Photos must get an upright file whose orientation is 1, or the result shows sideways. Test in Task 3.
2. **App settings that don't fit Photos** (PNG format, an export width of 1080): the extension must still save full size in a type Photos accepts, and the HDR badge mustn't say "HDR off" because the app happens to use PNG. Test in Task 3.
3. **Adjustment data that isn't readable** (another version, or bytes that don't decode): `canHandle` is false for other versions, and unreadable data starts from the app's settings instead of failing. Test in Task 3.
4. **Cancel**: with no change, Cancel closes without asking; after a change, Photos asks to discard. Checked on the device in Task 5.
5. **Settings changed in the app later**: re-editing a photo uses that photo's saved border, not the app's newer settings. Checked on the device in Task 5.

---

### Task 1: `BorderEditor`, the Edit page's settings without `DataModel`

**Files:**
- Create: `multiborder/BorderEditor.swift` (moves to `EditingUI/` in Task 2)
- Modify: `multiborder/DataModel.swift` (the `settings` property and `init`, ~lines 108–160)
- Modify: `multiborder/EditView.swift` (every `@Environment(DataModel.self)` and `data.settings`; 51 uses, all of them settings)
- Modify: `multiborder/MainView.swift` (inject the editor)
- Test: `multiborderTests/swift_multiborderTests.swift` (`DataModelTests`)

**Interfaces:**
- Produces: `@MainActor @Observable final class BorderEditor { var settings: BorderSettings; @ObservationIgnored var onChange: (() -> Void)?; init(settings: BorderSettings, savingTo defaults: UserDefaults?) }`. Saves to `defaults` on every real change (when not nil), then calls `onChange`.
- Produces: `DataModel.editor: BorderEditor` (`let`). `DataModel.settings` stays, as a computed property forwarding to `editor.settings`, so `ExportView`, `SettingsView`, `ImageViews`, sharing and the tests keep working. The old `didSet` work (`savedIDs.removeAll()`, `resetSaveStatus()`) moves into `editor.onChange`.

- [ ] **Step 1: Write the failing tests** in `DataModelTests`:

```swift
@Test func editorWithoutDefaultsNeverSaves() {
    let defaults = makeDefaults()
    let editor = BorderEditor(settings: BorderSettings.load(from: defaults), savingTo: nil)
    editor.settings.aspectRatio = .square
    #expect(BorderSettings.load(from: defaults).aspectRatio == BorderSettings().aspectRatio)
    #expect(!BorderSettings.isSaved(in: defaults))
}

@Test func editingThroughTheEditorSavesAndResetsTheModel() {
    let defaults = makeDefaults()
    let model = DataModel(defaults: defaults)
    model.editor.settings.aspectRatio = .square
    #expect(model.settings.aspectRatio == .square)
    #expect(DataModel(defaults: defaults).settings.aspectRatio == .square)
    #expect(model.saveStatus == .unsaved)
}
```

- [ ] **Step 2: Run the tests**, expect a build failure: `cannot find 'BorderEditor' in scope`.
- [ ] **Step 3: Implement `BorderEditor`** and switch `DataModel` to it as in Interfaces.
- [ ] **Step 4: Point the Edit page at the editor.** In `EditView.swift`, every `@Environment(DataModel.self) private var data` becomes `@Environment(BorderEditor.self) private var editor`, `data.settings` → `editor.settings`, `Bindable(data).settings` → `Bindable(editor).settings`, `$data.settings` → `$editor.settings` (with `@Bindable var editor = editor` where `$data` was used). In `MainView`, add `.environment(data.editor)` next to `.environment(data)`.
- [ ] **Step 5: Run the whole test suite**, expect all pass (including the existing `settingsPersistAcrossLaunches`).
- [ ] **Step 6: Commit** `Move the Edit page's settings into BorderEditor`.

### Task 2: `EditingUI/`, the Edit page shared between the app and an extension

**Files:**
- Create folder `EditingUI/` and move into it (with `git mv`): `multiborder/EditView.swift`, `multiborder/DefaultPage.swift`, `multiborder/FeatureTips.swift`, `multiborder/BorderEditor.swift`, `multiborder/Assets.xcassets`.
- Create: `EditingUI/BorderedImage.swift`: `BorderedImage` and `HDRBadge` moved out of `multiborder/Images/ImageViews.swift`, plus `BorderedPreview` (below).
- Create: `EditingUI/Fonts.swift`: the `Font.spaceMono(_:)` extension moved out of `multiborder/multiborderApp.swift`.
- Modify: `multiborder/Images/ImageViews.swift` (`ImageContainerView`'s `.loaded` case uses `BorderedPreview`), `multiborder/multiborderApp.swift` (the `-resetFeatureIntro` debug block moves here from `FeatureTips.configure()`, since `EditingUI` can't see `DataModel`), `multiborder/MainView.swift` (`EditView { ImageStack() }`).
- Modify: `multiborder.xcodeproj/project.pbxproj`: a `PBXFileSystemSynchronizedRootGroup` for `EditingUI` (ids `AE00000000000000000000A1…`), listed in the main group's children and in the `multiborder` target's `fileSystemSynchronizedGroups`, like `Shared` (`AB00000000000000000000A5`).

**Interfaces:**
- Consumes: `BorderEditor` (Task 1).
- Produces: `EditView.init(@ViewBuilder preview: () -> some View)`, stored as `AnyView` so `EditView` stays non-generic and keeps `static let controlRowHeight`. The body puts `preview` where `ImageStack()` was.
- Produces: `struct BorderedPreview: View { let thumbnail: ImageComposer.Thumbnail; let settings: BorderSettings }`: the `GeometryReader` + `BorderedImage` + top-trailing `HDRBadge` that `ImageContainerView` draws today, unchanged.
- Produces: the color assets (`.stone*`, `.accent`) and `Font.spaceMono` available to any target compiling `EditingUI/`.

- [ ] **Step 1: Move the files and add the folder to the project** as listed. Nothing in `EditingUI/` may reference `DataModel`, `ImageAttachment`, `TabbedItems`, `WhatsNew` or `ImageStack`; check with `grep -n "DataModel\|ImageAttachment\|TabbedItems\|WhatsNew\|ImageStack" EditingUI/*.swift` (expect no output).
- [ ] **Step 2: Run the whole test suite**, expect all pass. A build failure here is a missed reference; fix it in place.
- [ ] **Step 3: Install on the iPhone and compare the Edit page** with the previous build: toggles, sliders, caption row, preview, HDR badge, tips, `-resetFeatureIntro`. Expect no visible change.
- [ ] **Step 4: Commit** `Share the Edit page through EditingUI`.

### Task 3: `PhotoEditing`, the PhotoKit glue, and the canvas budget

**Files:**
- Create: `Shared/PhotoEditing.swift`
- Modify: `Shared/ImageComposer.swift:354` (`maxCanvasBytes`)
- Test: `multiborderTests/swift_multiborderTests.swift` (new `@Suite struct PhotoEditingTests`)

**Interfaces:**
- Produces, in `nonisolated enum PhotoEditing`:
  - `static let formatIdentifier = "com.adamhp.multiborder.border"`, `static let formatVersion = "1"`
  - `static func adjustmentData(for settings: BorderSettings) throws -> PHAdjustmentData`
  - `static func canHandle(_ data: PHAdjustmentData) -> Bool`: identifier and version both match.
  - `static func settings(from data: PHAdjustmentData?) -> BorderSettings?`: nil unless `canHandle` and the data decodes.
  - `static func outputFormat(defaultType: UTType?) -> ExportFormat`: `.heic` when `defaultType` conforms to `.heic`, otherwise `.jpeg` (both carry the gain map, so HDR survives either).
  - `static func editingSettings(_ settings: BorderSettings, format: ExportFormat) -> BorderSettings`: a copy with `exportWidth = 0` and `exportFormat = format`. The extension edits and saves this copy, so the preview's HDR badge and the render agree with what Photos gets.
- Produces: `ImageComposer.usesSmallCanvas(_ info: [String: Any]?) -> Bool`: true only when `info` has an `NSExtension` whose `NSExtensionPointIdentifier` isn't `com.apple.photo-editing`. `maxCanvasBytes` becomes `usesSmallCanvas(Bundle.main.infoDictionary) ? 40_000_000.0 : 400_000_000.0`, replacing the `.appex` path check.

- [ ] **Step 1: Write the failing tests:**

```swift
@Suite struct PhotoEditingTests {
    @Test func settingsRoundTripThroughAdjustmentData() throws {
        var settings = BorderSettings()
        settings.aspectRatio = .square
        settings.isPerSide = true
        settings.sides = BorderInsets(uniform: 0.07)
        let data = try PhotoEditing.adjustmentData(for: settings)
        #expect(data.formatIdentifier == "com.adamhp.multiborder.border")
        #expect(data.formatVersion == "1")
        #expect(PhotoEditing.canHandle(data))
        #expect(PhotoEditing.settings(from: data) == settings)
    }

    @Test func otherAdjustmentsAreNotOurs() {
        let other = PHAdjustmentData(formatIdentifier: "com.apple.photo", formatVersion: "1", data: Data())
        let future = PHAdjustmentData(formatIdentifier: PhotoEditing.formatIdentifier, formatVersion: "2", data: Data())
        let garbled = PHAdjustmentData(formatIdentifier: PhotoEditing.formatIdentifier, formatVersion: "1", data: Data("x".utf8))
        #expect(!PhotoEditing.canHandle(other))
        #expect(!PhotoEditing.canHandle(future))
        #expect(PhotoEditing.settings(from: other) == nil)
        #expect(PhotoEditing.settings(from: garbled) == nil)
        #expect(PhotoEditing.settings(from: nil) == nil)
    }

    @Test func editingIgnoresTheAppsExportWidthAndFormat() {
        var app = BorderSettings()
        app.exportWidth = 1080
        app.exportFormat = .png
        let editing = PhotoEditing.editingSettings(app, format: PhotoEditing.outputFormat(defaultType: .heic))
        #expect(editing.exportWidth == 0)
        #expect(editing.exportFormat == .heic)
        #expect(PhotoEditing.outputFormat(defaultType: .jpeg) == .jpeg)
        #expect(PhotoEditing.outputFormat(defaultType: nil) == .jpeg)
    }

    @Test func onlyTheShareSheetGetsTheSmallCanvas() {
        func ext(_ point: String) -> [String: Any] { ["NSExtension": ["NSExtensionPointIdentifier": point]] }
        #expect(!ImageComposer.usesSmallCanvas(nil))
        #expect(!ImageComposer.usesSmallCanvas([:]))
        #expect(ImageComposer.usesSmallCanvas(ext("com.apple.share-services")))
        #expect(ImageComposer.usesSmallCanvas(ext("com.apple.ui-services")))
        #expect(!ImageComposer.usesSmallCanvas(ext("com.apple.photo-editing")))
    }

    @Test func fullSizeRenderOfARotatedPhotoIsUpright() async throws {
        let source = try #require(hdrPhoto(orientation: 6))   // existing fixture helper
        let settings = PhotoEditing.editingSettings(BorderSettings(), format: .jpeg)
        let output = try await ImageComposer.render(source, settings: settings)
        let image = try #require(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        // Portrait in, portrait out: the canvas is taller than wide for the default ratio's portrait layout.
        let width = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(height > width)
    }
}
```

Check `hdrPhoto(orientation:)`'s return type and the fixture's shape before relying on the last assertion; if the default ratio's layout makes the comparison meaningless for that fixture, compare against the upright source size instead (`ImageComposer.layout(sourceSize:settings:).canvasSize`).

- [ ] **Step 2: Run the tests**, expect a build failure: `cannot find 'PhotoEditing' in scope`.
- [ ] **Step 3: Implement `PhotoEditing` and `usesSmallCanvas`** as in Interfaces.
- [ ] **Step 4: Run the whole test suite**, expect all pass.
- [ ] **Step 5: Commit** `Add the Photo Editing glue and give it the app's canvas budget`.

### Task 4: The `EditBorderExtension` target

**Files:**
- Create: `EditBorderExtension/PhotoEditingViewController.swift`
- Create: `EditBorderExtension/EditingScreen.swift`
- Create: `EditBorderExtension/Info.plist`, `EditBorderExtension/EditBorderExtension.entitlements`
- Modify: `multiborder.xcodeproj/project.pbxproj`: a new app-extension target (ids `AD00000000000000000000A1…`) copied from `AddBorderAction` (`AC…`): product `EditBorderExtension.appex`, bundle id `com.adamhp.multiborder.EditBorder`, synchronized groups `Shared`, `EditingUI`, `EditBorderExtension` (with an exception set excluding its `Info.plist`), `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `MARKETING_VERSION = 3.0.0`, `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = accent`, the same Swift settings as `AddBorderAction` (Swift 6, default MainActor isolation, upcoming features). Embed it in the app's existing "Embed Foundation Extensions" copy phase and add a target dependency, as for `AddBorderAction`.

**Interfaces:**
- Consumes: `BorderEditor` (Task 1); `EditView(preview:)`, `BorderedPreview`, `Font.spaceMono` (Task 2); `PhotoEditing.*`, `ImageComposer.thumbnail(from:filename:maxPixelSize:)`, `ImageComposer.render(_:filename:settings:)` (Task 3); `BorderSettings.load(from: .appGroup)`.
- Produces: `final class PhotoEditingViewController: UIViewController, PHContentEditingController`.

Info.plist: `CFBundleDisplayName` = `multiborder`; `NSExtension` → `NSExtensionPointIdentifier` = `com.apple.photo-editing`, `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).PhotoEditingViewController`, `NSExtensionAttributes` → `PHSupportedMediaTypes` = [`Image`]; `UIAppFonts` with the same seven fonts as `AddBorderAction/Info.plist`. Entitlements: the App Group only.

Behavior of `PhotoEditingViewController`:
- `canHandle(_:)`: returns `PhotoEditing.canHandle(data)`; when it returns false, remembers `hasOtherEdits = true` (Photos only asks when the photo already has an adjustment).
- `startContentEditing(with:placeholderImage:)`: keeps the input; picks `format = PhotoEditing.outputFormat(defaultType:)` from a `PHContentEditingOutput(contentEditingInput:)`'s `defaultRenderedContentType`; starting settings are `PhotoEditing.settings(from: input.adjustmentData) ?? BorderSettings.load(from: .appGroup)`, passed through `PhotoEditing.editingSettings(_:format:)`; makes `BorderEditor(settings:savingTo: nil)`; reads the photo from `input.fullSizeImageURL`, builds the thumbnail (`ImageAttachment.thumbnailPixelSize`'s value, 1024) and hosts `EditingScreen` in a `UIHostingController` child filling the view, with `.environment(editor)`, `.preferredColorScheme(.dark)` and `.environment(\.font, .spaceMono(14))` as the app does.
- Filename for the caption: the URL's last path component, or nil when it starts with `FullSizeRender` (Photos' name for an earlier edit's render). Log the name once on the device in Task 5 to confirm.
- `finishContentEditing(completionHandler:)`: shows `EditingScreen`'s saving overlay, renders the original data with `editor.settings` (`format` from above), writes it to `output.renderedContentURL(for: <the chosen UTType>)`, sets `output.adjustmentData = PhotoEditing.adjustmentData(for: editor.settings)`, and calls the handler with the output; on any error, calls it with nil.
- `shouldShowCancelConfirmation`: `editor.settings != starting settings`.
- `cancelContentEditing()`: nothing to clean up beyond dropping references.

`EditingScreen` (SwiftUI): the other-edits note (exact copy from Global Constraints, `.spaceMono(12)`, `.stone400`, above the page) when `hasOtherEdits`; `EditView { BorderedPreview(thumbnail:settings:) }` (a `ProgressView` until the thumbnail is ready, the same warning triangle as the app if it fails); and while saving, a dimmed overlay with a `ProgressView` and "Adding border…". Background: the app's `stone800`→`stone900` gradient.

- [ ] **Step 1: Add the target, files and plist** as listed.
- [ ] **Step 2: Build for the iPhone** with the device build command; expect success. Then run the whole test suite on the simulator; expect all pass.
- [ ] **Step 3: Commit** `Add the Photo Editing Extension`.

### Task 5: Device check and docs

**Files:**
- Modify: `docs/code-review-modernize.md` (a new Done entry; remove the Photo Editing Extension from "iOS features worth adopting"), `multiborder/TODO.md` (remove the Photo Editing Extension line)

- [ ] **Step 1: Install on the iPhone** and check in Photos (Edit → … → multiborder), with results noted for the doc:
  1. A 48 MP photo: the extension opens, the border edits live, Done saves, and the saved photo has every pixel plus the border (check its size in Photos' info panel). Note whether memory held.
  2. A portrait photo comes back upright.
  3. Re-edit: Edit → multiborder again shows that photo's border, not the app's current settings (change the app's settings first); changing it replaces the border rather than adding a second one. Revert restores the original.
  4. Cancel without changes closes; after a change, Photos asks to discard.
  5. A photo cropped in Photos after a border shows the other-edits note, and editing still works.
  6. An HDR photo keeps its highlights after Done; the app's own settings are unchanged afterwards.
  7. The caption's filename: note what the extension received.
- [ ] **Step 2: Update the docs** with what was built and checked, in the doc's existing style.
- [ ] **Step 3: Commit** `Note the Photo Editing Extension in the docs`.
