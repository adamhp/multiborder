# Photo Editing Extension

## Intent

Add borders to a photo from inside Photos. A person opens a photo in Photos, taps Edit, chooses multiborder from the extensions menu, and gets the app's Edit page for that one photo. Tapping Done hands the bordered photo back to Photos, which saves it in place, and Photos' Revert undoes it. It's on `multiborder/TODO.md` and the review doc's "iOS features worth adopting".

## Goals

- **Everything the app's Edit page does,** for the one photo: aspect ratio and landscape, border width or a width per side, color or blurred fill, rounded corners, shadow, and the photo-details caption with its layout, font and icon options.
- **The same result as the app.** The bordered photo comes from the same renderer as Download (`ImageComposer`), so a border made in Photos matches one made in the app with the same settings.
- **Editable later.** The border's settings are saved with the edit (`PHAdjustmentData`). Opening the photo again, tapping Edit and choosing multiborder brings those settings back to adjust. Photos then provides the original photo, so the border is redrawn rather than stacked on the last one.
- **A first edit starts from the app's last-used settings**, so it looks like what the app would make.
- **Full size.** The photo keeps every pixel Photos gave it, and the canvas grows around it for the border, as Download does at its original width (so a 48 MP photo with a border comes back a little larger than 48 MP, in the border's aspect ratio). Not the app's export width.
- **HDR is kept** when the photo has an ISO gain map, as Download does (iOS 18+, and only in a format that can hold it).

## Non-goals

- More than one photo. Photos opens an editing extension for a single photo, so there's no card stack, Clear tab, Select or Export page.
- Export controls: width, format, album, original date. Photos decides the file and keeps the date and album.
- Tips and the What's New sheet.
- Designing around the extension's memory limit up front. The owner will test with a 48 MP photo; problems are handled when they show up.
- Video and Live Photo motion.

## Anti-goals

- Editing in Photos must not change the app's last-used settings, or the share-sheet entries' settings. The app and the share sheet keep their own, shared through the App Group as now; a photo's border stays with that photo.
- The extension must not render differently from the app.
- It must not leave the app's Edit page worse: sharing that page with the extension can't change how it looks or behaves in the app.

## Constraints

- **Platform:** a Photo Editing Extension target (`com.apple.photo-editing`) with a `PHContentEditingController` view controller, iOS 17+ like the app, built with Swift and SwiftUI like the rest of the project, in the same project and App Group as the other extensions. It needs `PHSupportedMediaTypes` = Image.
- **Saving:** `finishContentEditing` writes a rendered file to the `PHContentEditingOutput` and sets its `adjustmentData`. On iOS 17+ the output offers `supportedRenderedContentTypes` and `renderedContentURL(for:)`, so the file can be HEIC where Photos accepts it (needed for HDR) and JPEG otherwise. The adjustment data's format identifier and version are this extension's, and `canHandle(_:)` returns true for them, so re-edits get the original photo plus the saved settings.
- **Memory budget:** `ImageComposer.maxCanvasBytes` is 40 MB (about 10 MP) in any `.appex`, for the share-sheet entries. This extension uses the app's 400 MB budget instead, so the share-sheet entries keep their cap and this one renders full size. Whether that fits the editing extension's memory limit is what the 48 MP test on the iPhone 16 Pro checks.
- **Settings storage:** the saved settings are `BorderSettings`, encoded as now (it's `Codable`, and decoding fills missing keys with defaults, so settings saved by an older version still load). The App Group defaults are read, never written, from the extension.
- **The Edit page's code lives in the app target** (`multiborder/EditView.swift`, `Images/ImageViews.swift`, `CardStack.swift` and others) and reads a `DataModel` from the environment. `DataModel` saves every settings change to the defaults it was given. The extension has to reuse that page, not copy it, and must not save to the App Group.
- **Caption details** come from the photo's metadata (`PhotoCaption.photoItems(from:metadata:filename:)`). The editing input gives the photo's file URL; the filename it carries may not be the name Photos shows.

## Decided

- The extension's screen is the app's Edit page, with the photo in place of the card stack, plus Photos' own Cancel and Done.
- One photo, full size, saved in place by Photos.
- First edit: the app's last-used settings. Re-edit: the photo's saved settings.
- Nothing written back to the app's settings.
- Memory limits are tested, not designed for in advance: the extension renders full size with the app's canvas budget.
- **Photos with other edits on top:** when Photos can't hand over the original (the latest edit isn't multiborder's, for example a crop or filter in Photos after a border), the extension still opens and edits normally, with a short note that doesn't block anything: the photo has other edits, the border is added on top of them, and to change a border added earlier, revert the photo in Photos first. The extension can't tell whether a multiborder border is underneath, so the note doesn't claim one is.

## Left to the builder

- How the Edit page is shared with the extension target: moving files to `Shared/`, adding them to the extension's sources the way `AddBorderAction` compiles `AddBorderExtension/`, or another split. The app's behavior mustn't change.
- How `DataModel` (or a smaller model the Edit page reads) runs without saving: for example a defaults store that isn't the App Group, or a flag. The extension needs one photo as its only attachment, the app's settings to start from, and no persistence.
- Which rendered format to use when both are offered (HEIC when the photo is HDR and HDR is kept, otherwise Photos' default type seems right).
- Whether the "Keep HDR" setting from the app applies here (it's part of `BorderSettings`, so it would come along with the app's settings).
- What to show while the full-size render runs after Done, and how an error is reported. Photos can only be told the edit failed by handing back no output.
- The extension's display name and icon in Photos' menu. Photos shows the app icon; the name is the bundle display name.
- What the caption's filename shows if the input's file name isn't the photo's own (hide it, or use what's there).
- `shouldShowCancelConfirmation`: probably true once the border has changed.
- Tests: what can be covered in unit tests (adjustment data round-trip, rendering the input's photo with given settings) beside a check on the iPhone 16 Pro.
