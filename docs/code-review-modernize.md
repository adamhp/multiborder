
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