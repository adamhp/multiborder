# Website Refresh and Demo Videos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh multiborder.io for 3.0 (rating, reviews strip, "New in 3.0" section) and
produce the App Store preview, the hero demo and two spotlight videos.

**Architecture:** The website work is four tasks in `~/dev/multiborder-website` on branch
`refresh-3.0`. Shared review data and the rating live in one module; three new components
sit on the home page, and `/features` reuses the new section. The video work is in
`multiborder-2.0` on `modernize`. A launch argument puts the app into a clean demo state,
and a gated UI test drives the storyboard while `simctl` records. A HyperFrames project
then turns that footage into the captioned App Store preview and the uncaptioned hero demo,
and also renders the two photo-only spotlight loops. The final task drops the videos into the
site and opens a draft PR that stays unmerged until 3.0.0 is live.

**Tech Stack:** Next.js 16, React 19, Tailwind 4, Swift/XCUITest, `xcrun simctl`,
HyperFrames (`npx hyperframes`, GSAP timelines), ffmpeg.

**Spec:** `docs/superpowers/specs/2026-11-03-website-refresh-and-demo-videos-design.md`

## Global Constraints

- **Rating:** the single constant `appStoreRating = 4.6`, shown as "★★★★★ 4.6 on the App Store" (hero) and "4.6" + five stars + "App Store rating" (strip).
- **Sources:** App Store: shawn_buso, _hugirl, DoctorBoyong. Ko-fi: Livi, Evan, Tom, Jenna. The 1★ "App is Crashing" review never appears.
- **Home-strip quotes:** shawn_buso, _hugirl, Jenna, in that order, plus a "Read all reviews →" link to `/reviews`.
- **Home page order:** Hero → ReviewsStrip → FeaturesSection (`id="features"`).
- **Spotlight names:** "Borders your way" and "Camera settings caption", taken from `multiborder/WhatsNew.swift`.
- **Six tiles:** Edit many photos at once · HDR stays HDR · Edit in Photos · Share sheet · Shortcuts · Saves where you want.
- **Look:** keep the existing site style: stone-800 background, amber-600 accent, Geist, `PhoneFrame`, `Container` and `Button`. No new UI libraries.
- **App Store preview:** 15–30s (target about 25s); 886×1920 portrait; 30 fps; H.264; ≤500 MB. All footage comes from the app; only captions are overlaid; it ends inside the app.
- **Recording device:** the iPhone 17 Pro Max Simulator on iOS 26.5, UDID `02636D4E-1A7B-4FFC-8584-36A9F3F35CB6`.
- **Sandbox:** run each `xcrun` or `xcodebuild` call as one bare command, with no `cd`, pipe, redirect or `&&`. Scripts that wrap them are for Adam to run in a normal terminal.
- **Sample photos:** `multiborder-2.0/sample-photos/IMG_2066–2074.JPG` at 1024px. Their camera data is real (LEICA CAMERA AG, LEICA Q3 43).
- **Release:** the website PR stays a draft until 3.0.0 is on the App Store.

## Review Focus

1. **Phone width (390px):** the strip stacks with the rating card first, the hero rating line sits under the description, the spotlights stack text-above-video, and the page has no horizontal scroll. Tasks 2–4 each check this at 390px.
2. **Light colour scheme:** `globals.css` switches `--background` to light under `prefers-color-scheme: light`. The new sections must stay readable in both schemes. Tasks 3 and 4 check light and dark screenshots.
3. **Reduced motion and video failure:** spotlight videos are muted, `playsInline` and looped, and have a poster. With `prefers-reduced-motion: reduce` they show the poster and don't autoplay. A missing file still shows the poster. Task 4 pins this.
4. **Leftover Simulator state:** What's New, tips, earlier border settings or an empty photo library would ruin a take. Task 5's launch argument resets them, and Task 6 asserts a clean start.
5. **App Store rejection on technical specs:** a wrong size, fps, length or audio track. Task 8 checks the output with `ffprobe` against the constraints above.

---

## Website (`~/dev/multiborder-website`, branch `refresh-3.0`)

The site has no test runner. Each task's proof is `npm run lint` and `npm run build`
passing, plus a Playwright check against `npm run dev` (port 3000). Use the Playwright
MCP tools; local port binding is allowed.

### Task 1: Shared review data and source labels on `/reviews`

**Files:**
- Create: `src/content/reviews.ts`
- Modify: `src/components/Reviews.tsx`

**Interfaces:**
- Produces:
  ```ts
  export type ReviewSource = 'App Store' | 'Ko-fi';
  export type Review = { body: string; author: string; source: ReviewSource };
  export const appStoreRating = 4.6;
  export const featuredReview: Review;              // shawn_buso
  export const reviewColumns: Review[][][];          // same nesting and order as today's `testimonials`
  export const homeReviews: Review[];                // [shawn_buso, _hugirl, Jenna]
  ```
  `author` holds the display form: `@handle` for App Store reviews, a bare name for Ko-fi ones,
  matching what the page shows today.

- [ ] **Step 1:** `git switch -c refresh-3.0` in `~/dev/multiborder-website`.
- [ ] **Step 2:** Move the quotes out of `Reviews.tsx` into `src/content/reviews.ts`, keeping their text exactly, and add `source` to each one using the Global Constraints. `homeReviews` reuses the same objects; don't copy the text.
- [ ] **Step 3:** Change `Reviews.tsx` to read from the module, and add the source to each `figcaption`, right-aligned in `text-stone-500` (as in the mockup).
- [ ] **Step 4:** Run `npm run lint && npm run build`. Expected: both pass.
- [ ] **Step 5:** Playwright: open `/reviews`, and check that every `figure` contains exactly one of "App Store" or "Ko-fi", and that the page text doesn't contain "Crashing".
- [ ] **Step 6:** Commit: "Move reviews into shared data and label each quote's source".

### Task 2: Rating line in the hero

**Files:**
- Create: `src/components/RatingLine.tsx`
- Modify: `src/components/Hero.tsx`

**Interfaces:**
- Consumes: `appStoreRating` from Task 1.
- Produces: `export function RatingLine({ className }: { className?: string })`, which renders `★★★★★ 4.6 on the App Store`. The stars are amber (`text-amber-500`) and `aria-hidden`. The accessible text is "Rated 4.6 out of 5 on the App Store". It links to `appUrl`.

- [ ] **Step 1:** Build `RatingLine` as a small `text-sm` line, using the number from the constant.
- [ ] **Step 2:** In `Hero.tsx`, put one instance inside the `hidden md:block` QR wrapper just above `<QrDownload />`, and another `md:hidden` one directly under the description `<p>`.
- [ ] **Step 3:** Run `npm run lint && npm run build`. Expected: pass.
- [ ] **Step 4:** Playwright at 1280×900: exactly one visible element matches "4.6 on the App Store", and it sits above the QR image. At 390×844: one is visible, there is no QR, and `document.documentElement.scrollWidth <= 390`.
- [ ] **Step 5:** Commit: "Show the App Store rating in the hero".

### Task 3: Reviews strip on the home page

**Files:**
- Create: `src/components/ReviewsStrip.tsx`
- Modify: `src/app/(main)/page.tsx`

**Interfaces:**
- Consumes: `appStoreRating` and `homeReviews` from Task 1.
- Produces: `export function ReviewsStrip()`.

- [ ] **Step 1:** Build the strip inside `Container`. On `lg`, use a grid of `220px` plus three equal columns; on `sm`, two columns, with the rating card spanning both; below that, one column. The rating card has a subtle amber tint: a large "4.6", five stars, and "App Store rating". The quote cards reuse the `figure` styling from `Reviews.tsx`. Under the grid, add a centred "Read all reviews →" `Link` to `/reviews` in amber.
- [ ] **Step 2:** `page.tsx` renders `<Hero />` then `<ReviewsStrip />`.
- [ ] **Step 3:** Run `npm run lint && npm run build`. Expected: pass.
- [ ] **Step 4:** Playwright check of `/`:
  - The strip contains the three `homeReviews` bodies in order.
  - The link's `href` is `/reviews`.
  - At 390px, the rating card's top is above the first quote's top, and `scrollWidth <= 390`.
  - Take screenshots with `colorScheme` set to dark and to light; text is legible in both (check by eye).
- [ ] **Step 5:** Commit: "Add a reviews strip under the hero".

### Task 4: "New in 3.0" features section, replacing the old tabbed features

**Files:**
- Create: `src/components/FeaturesSection.tsx`, `src/components/SpotlightVideo.tsx`, `src/content/features.ts`, `public/videos/border-styles.jpg`, `public/videos/camera-caption.jpg`
- Modify: `src/app/(main)/page.tsx`, `src/app/(main)/features/page.tsx`, `src/components/Hero.tsx:96` (the link target)
- Delete: `src/components/Features.tsx`, `public/feature1.mp4`, `public/feature2.mp4`, `public/feature3.mp4`, and `src/components/CircleBackground.tsx` if nothing else imports it (check with grep)

**Interfaces:**
- Produces:
  ```ts
  // src/content/features.ts
  export type Spotlight = { title: string; body: string; points: string[]; video: string; poster: string };
  export type Tile = { title: string; body: string; icon: (p: React.ComponentPropsWithoutRef<'svg'>) => JSX.Element };
  export const spotlights: Spotlight[];  // [Borders your way, Camera settings caption]
  export const tiles: Tile[];            // the six, in Global Constraints order
  // components
  export function FeaturesSection();     // <section id="features">
  export function SpotlightVideo({ src, poster, label }: { src: string; poster: string; label: string });
  ```
  Video paths: `/videos/border-styles.mp4` and `/videos/camera-caption.mp4`. The posters
  are the same names with `.jpg`.

- [ ] **Step 1:** Write `features.ts`, basing the copy on the What's New and tip text:
  - **Borders your way:** a different width for each side, rounded corners, a shadow, or a soft blur of the photo filling the border.
  - **Camera settings caption:** the date taken, title, filename, your handle, camera, focal length, aperture, shutter speed and ISO, above and below the photo. You can drag details into place and choose the font and icons.
  - **Tiles:** the six from the spec. The saving tile covers the album, the format, the original date and background downloads.
  - **Icons:** single-colour SVGs in the style of the old `Features.tsx` icons (white at 85% opacity).
- [ ] **Step 2:** Build `SpotlightVideo`: a `<video muted loop playsInline poster>` in a `rounded-2xl` 4:3 box. It autoplays only when `matchMedia('(prefers-reduced-motion: reduce)')` is false; otherwise it shows the poster. If the video fails to load, the poster stays. It carries an `aria-label` that describes the video, for example "Corners rounding and a shadow fading in".
- [ ] **Step 3:** Build `FeaturesSection`:
  - An eyebrow "New in 3.0" and a heading (the builder writes it).
  - Two spotlight rows; the second is flipped on `lg`, and both stack text-first below `lg`.
  - A three-column tile grid: two columns on `sm`, one column on phones.
- [ ] **Step 4:** Posters for now: run `ffmpeg -i …/sample-photos/IMG_2069.JPG -vf scale=1440:-2,crop=1440:1080 public/videos/border-styles.jpg`. Do the same with `IMG_2071.JPG` for `camera-caption.jpg`. Task 9 replaces both with real frames.
- [ ] **Step 5:** The home page renders Hero, then ReviewsStrip, then FeaturesSection. `/features` renders `<FeaturesSection />` inside `Container`. In the hero, change the button link from `/features` to `/#features`. Delete the old files, then `grep -rn "Features'\|PrimaryFeatures\|feature[123].mp4" src` to confirm nothing still references them.
- [ ] **Step 6:** Run `npm run lint && npm run build`. Expected: pass.
- [ ] **Step 7:** Playwright check:
  - On `/`, `#features` contains both spotlight titles and six tile headings.
  - `/features` shows the same section.
  - At 390px, `scrollWidth <= 390`.
  - With `emulateMedia({ reducedMotion: 'reduce' })`, each spotlight `video.paused === true` and the poster is set.
  - With the `.mp4` still missing, the poster image is visible.
  - Take light and dark screenshots of the section.
- [ ] **Step 8:** Commit: "Replace the features tabs with a New in 3.0 section".

---

## Videos (`multiborder-2.0`, branch `modernize`)

### Task 5: Demo-recording launch argument

**Files:**
- Modify: `multiborder/multiborderApp.swift:22-28`
- Test: `multiborderUITests/swift_multiborderUITests.swift`

**Interfaces:**
- Produces: launch argument `-demoRecording`. When it is set, at launch:
  - `WhatsNew.release` is stored under `DataModel.whatsNewVersionKey`, so the sheet doesn't show.
  - `FeatureTips.isEnabled` is set to `false`.
  - The saved border settings in `UserDefaults.appGroup` are cleared, so the editor opens on the defaults. The builder finds the key in `BorderEditor`/`BorderSettings`.

- [ ] **Step 1:** Write the failing UI test `testDemoRecordingLaunchIsClean`. It launches with `["-resetFeatureIntro", "-demoRecording"]` and asserts that the "Select" tab exists within 5s and that `app.staticTexts["What’s New"].exists == false`.
- [ ] **Step 2:** Run it, bare: `xcodebuild test -quiet -project /Users/adam/dev/multiborder-2.0/multiborder.xcodeproj -scheme multiborder -destination 'platform=iOS Simulator,id=02636D4E-1A7B-4FFC-8584-36A9F3F35CB6' -only-testing:multiborderUITests/multiborderUITests/testDemoRecordingLaunchIsClean`. Expected: FAIL, because the What's New sheet shows.
- [ ] **Step 3:** Handle `-demoRecording` in `multiborderApp.init`, after the `-resetFeatureIntro` block, so it wins when both are passed.
- [ ] **Step 4:** Re-run the same command. Expected: PASS. Also run `-only-testing:multiborderTests`; it should still pass.
- [ ] **Step 5:** Commit: "Add a -demoRecording launch argument for clean demo takes".

### Task 6: Storyboard UI test

**Files:**
- Create: `multiborderUITests/DemoRecordingUITests.swift`

**Interfaces:**
- Consumes: `-demoRecording` from Task 5.
- Produces: `DemoRecordingUITests.testStoryboard()`. It is skipped with `XCTSkip` unless `ProcessInfo.processInfo.environment["DEMO_RECORDING"] == "1"`. xcodebuild passes that through when given `TEST_RUNNER_DEMO_RECORDING=1`. It plays the spec's five beats with pauses, so the video reads at normal speed:

  | Beat | Actions (labels from the app) | Hold |
  |---|---|---|
  | 0–4s | In the inline picker on Select, tap 4 sample photos | 1s |
  | 4–10s | Edit tab; drag "Border Width"; tap 2 colour swatches; tap "Aspect Ratio 4:5" | 1s |
  | 10–16s | Toggle "Rounded Corners", drag "Corner Radius"; toggle "Shadow", drag "Shadow" | 1s |
  | 16–21s | Toggle "Camera Settings Caption"; open "Caption Style" and pick a second font | 1s |
  | 21–25s | Export tab; tap the download button; wait for the app's saved state | 2s |

  Use `.press(forDuration:thenDragTo:)` for slider drags, so they move visibly. The builder
  confirms each label in `EditView.swift` and `ExportView.swift`. If one can't be found
  reliably, add an `accessibilityIdentifier` in the app, in a separate commit.

- [ ] **Step 1:** Load the photos, bare: `xcrun simctl boot 02636D4E-1A7B-4FFC-8584-36A9F3F35CB6`, then `xcrun simctl addmedia 02636D4E-1A7B-4FFC-8584-36A9F3F35CB6 /Users/adam/dev/multiborder-2.0/sample-photos/IMG_2066.JPG …` (all nine).
- [ ] **Step 2:** Write the test. The first assertion: the photo picker shows at least 4 photos. If it doesn't, the test fails with "Run simctl addmedia first".
- [ ] **Step 3:** Run it, bare: `xcodebuild test -quiet -project /Users/adam/dev/multiborder-2.0/multiborder.xcodeproj -scheme multiborder -destination 'platform=iOS Simulator,id=02636D4E-1A7B-4FFC-8584-36A9F3F35CB6' -only-testing:multiborderUITests/DemoRecordingUITests TEST_RUNNER_DEMO_RECORDING=1`. Expected: PASS, in 25–35s overall.
- [ ] **Step 4:** Run it again without `TEST_RUNNER_DEMO_RECORDING`. Expected: skipped, not failed.
- [ ] **Step 5:** Commit: "Add a UI test that plays the App Store preview storyboard".

### Task 7: Record the raw footage

**Files:**
- Create: `scripts/demo-videos/README.md`, `scripts/demo-videos/record.sh` (for Adam to run by hand)
- Output (ignored by git): `build/demo-videos/raw.mov`

- [ ] **Step 1:** Set the status bar, bare: `xcrun simctl status_bar 02636D4E-1A7B-4FFC-8584-36A9F3F35CB6 override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`.
- [ ] **Step 2:** Start recording in the background (bare, `run_in_background`): `xcrun simctl io 02636D4E-1A7B-4FFC-8584-36A9F3F35CB6 recordVideo --codec h264 --force /Users/adam/dev/multiborder-2.0/build/demo-videos/raw.mov`.
- [ ] **Step 3:** Run Task 6's test command.
- [ ] **Step 4:** Stop the recording with SIGINT: `pkill -INT -f "recordVideo"`. Confirm that `ffprobe build/demo-videos/raw.mov` shows a duration over 25s. If the sandbox blocks the signal, ask Adam to press Ctrl-C in the background task, or stop it with TaskStop.
- [ ] **Step 5:** Write `record.sh` to do Steps 1–4 in order, plus `addmedia`. Write the README with how to run it, the iPhone 17 Pro Max UDID, and the note that it has to run in a normal terminal.
- [ ] **Step 6:** Watch `raw.mov` by extracting frames at 2s, 7s, 13s, 18s and 23s, then look at them. Each should show the expected beat with no What's New and no tips. Commit the scripts: "Add the demo recording script".

### Task 8: App Store preview and hero demo (HyperFrames)

**Files:**
- Create: `scripts/demo-videos/hyperframes/` (from `npx hyperframes init`), `compositions/app-store-preview.html`, `compositions/hero-demo.html`, `scripts/demo-videos/render.sh`
- Output: `build/demo-videos/app-store-preview.mp4`, `build/demo-videos/hero-demo.mp4`

**Interfaces:**
- Consumes: `build/demo-videos/raw.mov`, trimmed to the storyboard window. Use the frames from Task 7 Step 6 to pick the in and out points.
- Produces: two MP4s at 886×1920 and 30 fps.

- [ ] **Step 1:** In `scripts/demo-videos/`, run `npx hyperframes init hyperframes`. Check `npx hyperframes --help` and the current docs (Context7 `/heygen-com/hyperframes`) for the composition attributes and the render flags. Add `node_modules` and `renders/` to a local `.gitignore`.
- [ ] **Step 2:** Make `app-store-preview.html`:
  - The root is 886×1920 with `data-duration` set to the trimmed length (24–26s), and the GSAP timeline is registered in `window.__timelines`.
  - The raw footage is a full-frame `<video class="clip">`, scaled to cover.
  - The five captions come from the spec, at the spec's times. Each is a short pill near the top of the screen that fades in over 0.3s and out over 0.3s.
  - Captions use Geist from Google Fonts. Nothing covers the app's controls during a beat.
- [ ] **Step 3:** Make `hero-demo.html`: the same footage window, with no captions, ending on a frame that loops back cleanly (a short crossfade to the first frame).
- [ ] **Step 4:** Render both with `--quality delivery --fps 30 -o`. Then add a silent stereo AAC track to the preview: `ffmpeg -i in.mp4 -f lavfi -i anullsrc=r=48000:cl=stereo -shortest -c:v copy -c:a aac -b:a 256k app-store-preview.mp4`. Check Apple's current App Preview spec page first; if it no longer requires audio, skip this. Compress the hero demo to under 6 MB (H.264, CRF tuned, `-movflags +faststart`, no audio).
- [ ] **Step 5:** Verify with `ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate -show_entries format=duration,size`:
  - The preview is h264 at 886×1920, 30/1 fps, 15–30s, with an aac stereo track and a size of 500 MB or less.
  - The hero demo is h264 at 886×1920 and under 6 MB.
  Extract a frame at each caption's midpoint and look at it.
- [ ] **Step 6:** Write `render.sh` to run Steps 4–5 again. Commit: "Add HyperFrames compositions for the App Store preview and hero demo".

### Task 9: Spotlight loops (HyperFrames)

**Files:**
- Create: `scripts/demo-videos/hyperframes/compositions/border-styles.html`, `.../camera-caption.html`, `.../assets/` (copies of the sample photos it uses)
- Output: `build/demo-videos/border-styles.mp4|.jpg`, `build/demo-videos/camera-caption.mp4|.jpg`

**Interfaces:**
- Produces: two silent 1440×1080, 30 fps loops of 8–10s each, under 4 MB each, plus a poster JPEG taken from the first frame.

- [ ] **Step 1:** `border-styles.html`:
  - A sample photo sits centred on a white border, over the site's stone background.
  - Over about 3s, the corner radius animates from 0 to about 6% of the short edge; then a soft shadow fades in; then the border width changes per side; then it eases back to the start.
  - The first and last frames match, so the loop is seamless.
  - Use CSS `border-radius` and `filter: drop-shadow` on the photo, and padding for the border.
- [ ] **Step 2:** `camera-caption.html`:
  - The same framing, using a different sample photo.
  - A caption row in Space Mono (Google Fonts, the app's caption font) types in under the photo, then crossfades to a second font. A second row above the photo appears with the date.
  - Use the photo's real camera data. Read it once with a throwaway Swift `CGImageSourceCopyPropertiesAtIndex` script, or with `sips -g all`, and hard-code the values in the composition. They are Leica Q3 43 values, so don't invent any.
  - The caption's layout follows the app's (look at a real export from the Simulator for reference).
- [ ] **Step 3:** Render both with `--quality delivery`, then re-encode to web H.264 (`-an -movflags +faststart`, under 4 MB). Pull frame 0 out as each poster JPEG.
- [ ] **Step 4:** Check the loops: compare the first and last frames side by side by extracting both. They should match. Check that each file is under 4 MB.
- [ ] **Step 5:** Add both to `render.sh`. Commit: "Add the spotlight loop compositions".

---

## Ship

### Task 10: Put the videos on the site and open the draft PR

**Files:**
- Modify (website): `public/demo.mp4` (replaced by `hero-demo.mp4`), `public/videos/border-styles.{mp4,jpg}`, `public/videos/camera-caption.{mp4,jpg}`

- [ ] **Step 1:** Copy the four outputs from `multiborder-2.0/build/demo-videos/` into the website's `public/`, and replace `demo.mp4`.
- [ ] **Step 2:** Run `npm run lint && npm run build`. Then a Playwright check on `/`:
  - The hero video plays (`currentTime > 0` after 2s).
  - Both spotlight videos play with motion allowed.
  - Take full-page screenshots at 1280 and 390 wide, in light and dark.
- [ ] **Step 3:** Commit: "Add the 3.0 demo and spotlight videos". Run `git push -u origin refresh-3.0`.
- [ ] **Step 4:** Open a **draft** PR with `gh pr create --draft`. Title it "Refresh the site for 3.0". The body summarises the changes, says "Do not merge until 3.0.0 is live on the App Store.", and ends with the attribution line.
- [ ] **Step 5:** Tell Adam:
  - How to preview locally: `npm run dev` in `~/dev/multiborder-website`.
  - That `build/demo-videos/app-store-preview.mp4` is ready to upload in App Store Connect.
  - The PR link.
