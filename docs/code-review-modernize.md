
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
- **Inline picker:** the Select tab shows the system photo picker in the page instead of a sheet. Each tap adds a photo to the batch in the order tapped, and a ✓ below the picker switches to the card stack. Leaving the tab also counts as Done, and clearing every photo brings the picker back. "Select some photos first!" takes the ✓'s place so it's readable instead of sitting over the picker. iOS shows a one-time "Private Access to Photos" notice the first time the picker appears. Tested on an iPhone 16 Pro.
- **Blurred photo fill:** a drop button next to the color well fills the border with the photo itself, scaled to cover the canvas and blurred, instead of the plain color. It's off by default. While it's on, a blur-strength slider (shown as 5–100% in steps of 5, default 40%, where 100 is a blur of 10% of the canvas) takes the color well's place. Strength is `BorderSettings.blurFraction`, measured against the canvas's shorter side, so the preview and every export size look equally soft. The export blurs a 512px copy and scales it up, which keeps it cheap at any canvas size. Builds and passes its unit tests on the iOS 26.5 simulator; the drop button and 4% default have been checked on the iPhone 16 Pro; the strength slider still needs checking there.
- **Separate border for each side:** a dashed-square button next to Border Width switches to four sliders, one along each edge of the preview, and the preview shrinks to make room. Each side starts at the current single width the first time, and keeps its value while the mode is off. The values are saved with the other settings and apply to the whole batch. Each side is a minimum gap and the photo is centered in the space left, so it's never cropped. The per-side widths are `BorderSettings.sides` (`BorderInsets`), switched on by `isPerSide`, and `layout` rounds each inset separately on the native-resolution path. Unit tests cover equal sides matching the single width and uneven sides keeping each width; on the native path the bottom gap can be up to 2px off from rounding.
- **Values in the slider thumb:** Border Width, Blur Strength and the edge sliders show their number inside the thumb. While dragging, it lifts onto a dark, thumb-sized pill and follows the thumb. It goes above the slider, below it for the bottom edge, and 84pt toward the photo for the left and right edges so it isn't hidden under your finger. The thumb's size is an estimate, since the system slider doesn't expose it.

Both were checked on the iPhone 16 Pro.

- **Photo details around the photo:** a caption button next to Border Width prints the photo's details in a row just above and a row just below it, the same in the preview, Download and Share. The details are the date taken, the title (IPTC or XMP title or caption), the filename, a handle (Instagram, Flickr, @, website or text only), the camera, focal length, aperture, shutter speed and ISO. Each is a pill above the border controls: drag it within or between the rows, and tap it for its options. A button at the start of each row spreads the row across the photo's width or groups it at the left, center or right. Text shrinks to fit the borders and the photo's width, and icons are as tall as the text's capitals. The work is in `PhotoCaption`, and its options are in `BorderSettings`.
- **Caption font and icons:** a cog to the right of the pills opens a menu with the caption's font and a switch for every icon at once. The fonts are DM Mono, DM Sans, IBM Plex Mono, Inter, JetBrains Mono, Space Grotesk and Space Mono (the default), all from Google Fonts and bundled through `UIAppFonts`. A saved font that's no longer offered falls back to Space Mono. Turning icons off keeps each detail's own icon setting for when they come back on.
  - The fonts are under the SIL Open Font License, which asks for each font's copyright notice and the licence to ship with it. `Settings.bundle` adds an Acknowledgements page to the app's entry in the Settings app (Settings → Apps → multiborder) with both. The same page shows the app's version and build, which the app writes to `UserDefaults` at launch, so it's blank until the first launch after installing. A font added later needs its copyright line from its `OFL.txt` added to `Settings.bundle/Acknowledgements.plist`.

Both were checked on the iPhone 16 Pro.

The Liquid Glass morph, hold-to-clear and the share sheet have since been checked on the iPhone 16 Pro.

Tried and dropped:

- Blurring the cards behind the front one in `CardStack`, meant to make overlapping photos of different shapes less distracting.
- A row of border color swatches sampled from the current photo's most common colors.

## iOS features worth adopting

- **Background export (iOS 26):** `BGContinuedProcessingTask` is a good fit for batch export. The work continues when the user leaves the app, with system progress UI. Your `exportProgress` already maps onto it.
- **HDR export (iOS 18+):** you deliberately export SDR today. ImageIO can now decode HDR (`kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR`) and write ISO gain maps (`kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap`). If you fill the border at SDR reference white, the border's color stays put while the photo keeps its HDR highlights. That would set the app apart from similar ones.
- **Shortcuts and Siri (App Intents):** `ImageComposer` doesn't depend on the UI, so an "Add border to photos" intent is cheap to build. It works in Shortcuts and Siri, and with iOS 26 can appear in Spotlight actions.
- **Photo Editing Extension:** this is also in your TODO. The compositor can be reused unchanged, and it lets people add a border from inside Photos.

## Feature ideas

- **Rounded corners or a shadow** on the photo inside the border.
- **Export options:** format (JPEG, HEIC or PNG), "save to album 'multiborder'", and an option to keep the original date. You currently set the date to now on purpose, and some users will want the other choice.
- **Match orientation per photo:** the landscape toggle applies to the whole batch, so a mix of portrait and landscape photos still shares one canvas shape. An option for each photo to follow its own orientation would fix that.
- **iPad and "Designed for iPad" on Mac:** the layout logic is already independent of resolution, so this is mostly UI work.
