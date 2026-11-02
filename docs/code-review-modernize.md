# Code Review: `modernize` branch

_Reviewed 2026-11-01 against `main...modernize` (through commit `2e32c5c`)._

I reviewed `main...modernize` by reading every source file, the project settings, CI and the tests. I didn't build or run the tests. Overall this is a strong modernization: the default MainActor setting with `@concurrent` ImageIO work is a clean concurrency design, the preview and export share one layout function, the tests use Swift Testing, and the accessibility work is thorough. Here's what I'd change.

## Bugs and risks

1. **Exports of 10-bit photos can use about twice the planned memory** (`ImageComposer.swift:85`, `:211`). The pixel limit is `maxCanvasBytes / 4`, which assumes 4 bytes per pixel. But `composite` switches to a 16-bit context when `bitsPerComponent > 8`, which is 8 bytes per pixel, so a 48MP 10-bit HEIC with a wide border could reach about 800MB for the canvas alone, plus the decoded source. I haven't confirmed that ImageIO returns more than 8 bits here, so test it on a device. A fix is to pass the bytes per pixel into `layout`, or to always composite at 8 bits since the output is SDR anyway.

2. **A fast double tap on Download can make export impossible to cancel** (`DataModel.swift:187`). `startExport` checks `saveStatus`, but `.saving` is only set once the task runs. Two taps in one run-loop pass create two tasks, and `exportTask` ends up pointing at the second one, which exits immediately. A later `exportTask?.cancel()`, from changing the selection or removing a photo, then misses the export that's actually running. Fix: set `saveStatus = .saving` inside `startExport`, or check `exportTask == nil`.

3. **Switching tabs loses your place in the stack** (`ImageViews.swift:30`). `.task { data.currentIndex = 0 }` runs each time a page appears. It works around `CardStack` keeping its own `@State currentIndex`/`previousIndex` copy of the binding, since a newly appearing stack wouldn't otherwise match. The fix is to give `CardStack` one source of truth: drive it from the binding and track only the drag in a `@GestureState` offset. That removes the `onChange` syncing and the reset.

4. **`CardStack` creates a view for every selected photo** (`CardStack.swift:32`). `PhotosPicker` has no `maxSelectionCount`, so 300 photos means 300 offset/scale/rotate views in one `ZStack`. Only about ±3 cards around the current one can be seen, so render just that window, or set a sensible selection limit.

5. **Smaller issues:**
   - `.sensoryFeedback(.success, trigger: !data.selection.isEmpty)` also fires on Start Over and when the last photo is removed. Use the `trigger:condition:` overload.
   - `removeCurrent` removes from `attachments` but leaves `selection` stale. That's harmless today, but you now have two lists that can drift apart.
   - The metadata scrub (`ImageComposer.swift:240`) removes GPS but keeps the IPTC dictionary, which can hold city, state and country. Consider removing `kCGImagePropertyIPTCDictionary` too, or at least its location fields.

## Project hygiene

- **Orphaned files:** `multiborder/kofi.png` and the whole `multiborder/Colors/zinc_*` folder aren't referenced by the project. Delete them.
- **Two app icon sets:** `Assets.xcassets/AppIcon.appiconset` is empty and `Images.xcassets/AppIcon.appiconset` has the real icon. Keep one catalog, which also gets rid of the duplicate-icon warning.
- **`SpaceMono.ttf` is in Copy Resources three times** (pbxproj lines 24–26), once per target. The test targets don't need it.
- **Xcode project format:** `objectVersion = 56` uses old-style groups. Converting to folders (file-system synchronized groups) in Xcode 16+ removes most pbxproj merge conflicts.
- **Deployment target 17.5:** nothing seems to need 17.5 specifically, so 17.0 would reach more devices. Or move to 18.0 if you want the HDR APIs below without availability checks.
- **Custom font:** `Font.custom("SpaceMono-Regular", size:)` is repeated about 20 times. Add a `Font.spaceMono(_:relativeTo:)` helper, or set it once in the environment, which you already do in `multiborderApp`, and only override sizes.
- **Export sizes:** the `sizes` array of tuples with `ForEach(id: \.self.0)` would read better as a small enum, like `AspectRatio`.
- **Swipe blocking:** the three nested `.gesture(DragGesture())` calls in `ExportView` that stop page swipes are fragile. If you keep the paged `TabView`, a single `.blocksSwipe(true)` on that container is clearer.
- **Localization:** `LOCALIZATION_PREFERS_STRING_CATALOGS` is on but there's no `Localizable.xcstrings`. Adding one is cheap since your `Text` literals are already localizable.
- **CI:** `actions/checkout@v4` can move to v5. Consider caching DerivedData and adding a Release build step, so warnings that only appear in optimized builds get caught.

## iOS features worth adopting

- **Background export (iOS 26):** `BGContinuedProcessingTask` is a good fit for batch export. The work continues when the user leaves the app, with system progress UI. Your `exportProgress` already maps onto it.
- **HDR export (iOS 18+):** you deliberately export SDR today. ImageIO can now decode HDR (`kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR`) and write ISO gain maps (`kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap`). If you fill the border at SDR reference white, the border's color stays put while the photo keeps its HDR highlights. That would set the app apart from similar ones.
- **Liquid Glass:** in `TabBar` you apply `.glassEffect` to the `GlassEffectContainer` itself as well as to the active item inside it, so glass sits on glass. The intended pattern is for the container to group sibling glass shapes. Give the active pill a `glassEffectID` in a namespace so it morphs between tabs.
- **App review prompt:** your button says "consider leaving a review" but there's no way to leave one. Call `@Environment(\.requestReview)` after the third or so successful export.
- **Sharing:** your TODO lists ShareLink. Make the rendered output `Transferable` (write it to a temporary file) and share straight to Instagram without going through the photo library.
- **Shortcuts and Siri (App Intents):** `ImageComposer` doesn't depend on the UI, so an "Add border to photos" intent is cheap to build. It works in Shortcuts and Siri, and with iOS 26 can appear in Spotlight actions.
- **Photo Editing Extension:** this is also in your TODO. The compositor can be reused unchanged, and it lets people add a border from inside Photos.
- **Inline picker (iOS 17):** `.photosPickerStyle(.inline)` with `.photosPickerDisabledCapabilities` can embed the picker in the Select tab instead of a modal, which saves a tap.

## Feature ideas

- **Landscape and Stories ratios:** every fixed ratio is portrait (2:3, 3:4, 4:5, 1:1), so a landscape photo is always put on a portrait canvas. Add a portrait/landscape toggle plus 9:16 for Stories and Reels.
- **Blurred photo fill:** filling the border with a blurred, scaled-up copy of the photo is the most requested option in apps like this. Your layout already gives you the rectangles.
- **Colors sampled from the photo:** offer a few border colors taken from the photo (dominant or average color), beyond the plain color picker.
- **EXIF caption:** you already keep EXIF, so you could print camera, lens, focal length, aperture, shutter speed and ISO in the border. That fits the Space Mono look well.
- **Uneven borders:** a heavier bottom border gives a Polaroid or gallery-mat look, and per-side padding is a small change to `layout`.
- **Rounded corners or a shadow** on the photo inside the border.
- **Export options:** format (JPEG, HEIC or PNG), "save to album 'multiborder'", and an option to keep the original date. You currently set the date to now on purpose, and some users will want the other choice.
- **iPad and "Designed for iPad" on Mac:** the layout logic is already independent of resolution, so this is mostly UI work.

## Priorities

The most important fixes are #1 and #2, and #3 is the most visible to users.
