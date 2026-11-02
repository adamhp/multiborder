
## Done

Landed in `6f2dd49`. They build and pass their unit tests on the iOS 26.5 simulator; the Liquid Glass morph, hold-to-clear and the review prompt still need checking by hand on a device.

- **Liquid Glass:** the `GlassEffectContainer` in `TabBar` now only groups the tab pills, and the bar behind them is a plain accent tint. The active pill has `glassEffectID("activeTab", in:)` in a shared namespace, so it morphs between tabs.
- **App review prompt:** `DownloadButton` calls `@Environment(\.requestReview)` after the third export that saves every photo. It asks at most once per app version and waits until the "Saved" confirmation has cleared.
- **Landscape and Stories ratios:** there's a new 9:16 ratio and an `isLandscape` setting. The orientation toggle takes the place of the icon at the start of the ratio row, and button labels flip to match (5:4, 16:9 and so on). `BorderSettings` now decodes missing keys as defaults, so settings saved before a field existed still load.
- **Hold to clear all:** tapping the X on the Select tab still removes the current photo. Holding it for 1.5s fills an accent ring, grows the button and plays haptics that get stronger, then removes every photo. VoiceOver gets a "Remove All Photos" action.

Added after `6f2dd49`:

- **Share sheet:** a share button next to Download opens the system share sheet with the whole batch, so photos go straight to Instagram and other apps without the photo library. Each photo is a `BorderedPhoto` (`Transferable`) that renders only when the chosen app asks for it. Tested on an iPhone 16 Pro with a single photo shared to Instagram.
  - Photos are shared as JPEG data, not as a file. Instagram's share extension rejected the file version with "Content currently unavailable" and accepts the data version.
  - Shared copies are always JPEG for compatibility; Download still keeps HEIC.
  - `ImageComposer.render` now runs one render at a time, so the share sheet loading several photos at once can't hold several large canvases in memory.
  - Sharing logs to the `com.adamhp.multiborder` subsystem, category `Share`, which made the Instagram problem traceable from a device log.

Tried and dropped: blurring the cards behind the front one in `CardStack`, meant to make overlapping photos of different shapes less distracting.

## iOS features worth adopting

- **Background export (iOS 26):** `BGContinuedProcessingTask` is a good fit for batch export. The work continues when the user leaves the app, with system progress UI. Your `exportProgress` already maps onto it.
- **HDR export (iOS 18+):** you deliberately export SDR today. ImageIO can now decode HDR (`kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR`) and write ISO gain maps (`kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap`). If you fill the border at SDR reference white, the border's color stays put while the photo keeps its HDR highlights. That would set the app apart from similar ones.
- **Shortcuts and Siri (App Intents):** `ImageComposer` doesn't depend on the UI, so an "Add border to photos" intent is cheap to build. It works in Shortcuts and Siri, and with iOS 26 can appear in Spotlight actions.
- **Photo Editing Extension:** this is also in your TODO. The compositor can be reused unchanged, and it lets people add a border from inside Photos.
- **Inline picker (iOS 17):** `.photosPickerStyle(.inline)` with `.photosPickerDisabledCapabilities` can embed the picker in the Select tab instead of a modal, which saves a tap.

## Feature ideas

- **Blurred photo fill:** filling the border with a blurred, scaled-up copy of the photo is the most requested option in apps like this. Your layout already gives you the rectangles.
- **Colors sampled from the photo:** offer a few border colors taken from the photo (dominant or average color), beyond the plain color picker.
- **EXIF caption:** you already keep EXIF, so you could print camera, lens, focal length, aperture, shutter speed and ISO in the border. That fits the Space Mono look well.
- **Uneven borders:** a heavier bottom border gives a Polaroid or gallery-mat look, and per-side padding is a small change to `layout`.
- **Rounded corners or a shadow** on the photo inside the border.
- **Export options:** format (JPEG, HEIC or PNG), "save to album 'multiborder'", and an option to keep the original date. You currently set the date to now on purpose, and some users will want the other choice.
- **Match orientation per photo:** the landscape toggle applies to the whole batch, so a mix of portrait and landscape photos still shares one canvas shape. An option for each photo to follow its own orientation would fix that.
- **iPad and "Designed for iPad" on Mac:** the layout logic is already independent of resolution, so this is mostly UI work.
