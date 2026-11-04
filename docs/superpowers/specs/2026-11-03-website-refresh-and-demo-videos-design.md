# Website refresh and demo videos for Multiborder 3.0

Date: 2026-11-03

## Intent

Multiborder 3.0 is about to ship (this `modernize` branch, version 3.0.0). The marketing
site (github.com/adamhp/multiborder-website) still describes 2.0: three features, a demo
video of the old app, and reviews hidden away on `/reviews`. The refresh has two jobs:

1. Tell visitors what is new in 3.0. Adam wants them to know about all of it, with
   **new border styles** (rounded corners, shadow) and **photo details** (captions) as the
   headline features.
2. Show social proof on the home page: the App Store rating and a few real reviews.

Alongside it, produce demo videos: an App Store app preview, a new hero demo for the
site, and two spotlight videos for the headline features.

Adam's view of the current site: "it does a pretty good job". This is a refresh, not a
redesign. Keep its look (dark stone background, amber-600 accent, Geist, the spinning
rings and phone frame in the hero).

## Goals

- The home page reads, top to bottom: **hero → reviews strip → "New in 3.0" features section**.
- The rating and real quotes appear on the home page.
- Every 3.0 feature is mentioned somewhere on the home page.
- The App Store preview is ready to upload in App Store Connect.
- The videos are reproducible: re-running a script regenerates them after UI changes.

## Non-goals

- Changing About, Support, Feedback, Privacy, the header or the footer.
- Fetching the rating live from Apple (see "Rating" below).
- Showing the share sheet, Shortcuts or Photos extensions in any video.
- iPad previews (the app is iPhone-only: `TARGETED_DEVICE_FAMILY = 1`).
- Localised previews or captions.
- Rewriting the hero's headline or description.

## Anti-goals

- **An App Store preview that Apple rejects.** Apple requires previews to show
  footage captured from the app itself. Captions and light overlays are fine; mocked-up or
  animated UI is not.
- **Making the site look templated or AI-generated**, or drifting from its existing style.
- **Showing the 1★ "crashing when exporting" review** anywhere.
- **Two copies of the same content drifting apart.** Quotes and feature text should each
  live in one place.

## Constraints

- **Site stack:** Next.js 16, React 19, Tailwind 4, framer-motion and headlessui, deployed
  on Netlify. Existing components to build on: `Hero.tsx`, `PhoneFrame.tsx`, `AppScreen.tsx`,
  `AppDemo.tsx` (plays `/demo.mp4`), `Reviews.tsx`, `Features.tsx` (the tabbed
  `PrimaryFeatures` with `feature1–3.mp4`), `QrDownload.tsx`, `Container.tsx`, and `Button.tsx`.
- **Local clone:** there is already one at `~/dev/multiborder-website`. A fresh clone was
  made for exploration in the session scratchpad. Start from whichever matches `origin`
  (the newest commit on the remote is `eebfdda Fix background/foreground colors broken by
  Tailwind v4 upgrade`).
- **App Store preview requirements (check them against Apple's current docs while
  building):** 15–30 seconds; 6.9" iPhone portrait at 886×1920; 30 fps or less; H.264 or
  ProRes; 500 MB or less. One preview at this size covers every iPhone.
- **Release timing:** build now. Adam previews the site locally, and the website PR is
  merged only after 3.0.0 is live on the App Store. Until then the work stays on a branch,
  and the videos can be re-recorded if the UI changes late.
- **Sample photos:** nine JPEGs, 1024px on the long edge, currently untracked in
  `multiborder-2.0/sample-photos/` (`IMG_2066–2074.JPG`, a mix of landscape and portrait).
  Adam said to try them at this size first. They belong in both repos.
- **Tooling on this Mac:** ffmpeg and Node 24. HyperFrames isn't installed yet. Simulator
  commands (`xcrun simctl …`) must run as commands that start with `xcrun` or `xcodebuild`
  (no `cd` prefix), or the sandbox blocks CoreSimulator. Local port binding is now allowed
  (`sandbox.network.allowLocalBinding: true`), so `next dev` and HyperFrames' renderer can
  run here. The sandbox only allows writes inside `multiborder-2.0`, so work in
  `~/dev/multiborder-website` needs that directory added to the session first.

## What Adam decided

### Home page: hero (kept)

- The layout, copy, QR code, spinning rings and phone mockup with the playing demo stay.
- **New:** a small rating line, "★★★★★ 4.6 on the App Store", just above the QR code. The
  QR block is hidden on phones, so there the line sits under the description instead.
- The demo in the phone is re-recorded for the 3.0 app (see Videos).

### Home page: reviews strip (option C from the mockups)

- A compact row directly under the hero: a rating card ("4.6", five stars, "App Store
  rating"), three quote cards, and a "Read all reviews →" link to `/reviews`.
- Each quote shows its source: "App Store" or "Ko-fi". Sources (from Adam and the App Store
  feed): **App Store** — shawn_buso, _hugirl, DoctorBoyong. **Ko-fi** — Livi, Evan, Tom, Jenna.
- On phones the rating card goes first, with the three quotes stacked below it.
- **Rating:** Adam chose **4.6**, combined from the US (4.3, 6 ratings), UK (5.0, 2) and
  Australia (5.0, 2) stores. Store it as one constant in the code, used by both the hero
  line and the strip, and update it by hand. Apple's public lookup API only gives one
  country at a time.

### `/reviews` page

- It keeps its current testimonial grid and quotes, and gains the same source label on
  each quote.

### Home page: "New in 3.0" features section (option A from the mockups)

- An eyebrow, "New in 3.0", and a heading.
- **Two spotlight rows** alternating text and video, named as the app's What's New names them
  (`multiborder/WhatsNew.swift`):
  - **Borders your way:** a different width for each side, rounded corners, a shadow, or a
    soft blur of the photo filling the border. The video leads with corners and shadow.
  - **Camera settings caption:** the date taken, title, filename, handle, camera, focal
    length, aperture, shutter speed and ISO, shown above and below the photo. You can drag
    them into place and choose the font and icons.
- **Six tiles** below: Edit many photos at once · HDR stays HDR · Edit in Photos (the
  Photo Editing Extension) · Share sheet (borders photos using your last settings) ·
  Shortcuts ("Add Border to Photos" action) · Saves where you want (choose the album and format, keep
  each photo's original date, and downloads keep going in the background).

### Videos

1. **App Store preview** (about 25 seconds, all real Simulator footage, with short captions):

   | Time | On screen | Caption |
   |---|---|---|
   | 0–4s | Select several sample photos | "Border all your photos at once" |
   | 4–10s | Drag the border size and colour controls; every photo updates | "Size, colour, aspect ratio" |
   | 10–16s | Turn on rounded corners and shadow | "New: rounded corners and shadows" |
   | 16–21s | Photo details appear under the photo, then the font changes | "New: photo details" |
   | 21–25s | Tap Download; end on the app's own saved/done state (stay inside the app) | "Ready to share" |

2. **Hero demo:** a new phone-screen recording of the 3.0 app that replaces
   `public/demo.mp4`. It is silent and loops, and it plays in the existing `PhoneFrame`
   and `AppScreen`. The current file is 393×952.
3. **Two spotlight videos (HyperFrames):** these show no app interface, only close-ups
   of the sample photos changing on their own. For border styles, the corners round off and
   a shadow fades in. For the camera settings caption, a real caption appears under the
   photo and its font changes. The sample photos carry real camera data (Leica Q3 43), so
   use their actual values, not made-up text. They are silent and loop smoothly. Adam will iterate on them if the first take
   doesn't work.

## Calls made by Claude (Adam can override these)

- `/features` shows the same new features section rather than the old tabbed
  `PrimaryFeatures`. The tabbed component and `feature1–3.mp4` are removed. The hero's
  "See more features" button links down to the features section on the same page.
- Every 3.0 feature in What's New is covered by the two spotlights and six tiles
  (per-side widths and the blurred border go in the "Borders your way" copy, and format and
  original date go in the saving tile), so the grid stays at six.
- The App Store preview ends inside the app, not in the Photos app, so all of its footage
  comes from the app itself.
- The three home-page quotes are shawn_buso and _hugirl (App Store) and Jenna (Ko-fi).
- Quotes live in one shared list that both the strip and `/reviews` read from.
- The App Store preview and the hero demo are both captured by driving the app with a UI
  test in `multiborderUITests` while `xcrun simctl io booted recordVideo` runs. The sample
  photos are loaded into the Simulator with `xcrun simctl addmedia`.
- Captions on the App Store preview are added with ffmpeg (or HyperFrames compositing the
  real footage), keeping the app footage itself unaltered.

## Left to the builder

- The exact heading for the features section and the wording of the spotlight and tile text.
  Use plain language, and use the app's own names for things.
- Icons for the six tiles. Follow the style of the existing SF Symbols-like SVGs in
  `Features.tsx`.
- HyperFrames setup, composition structure, timing, easing and output encoding. Check
  its current docs first.
- Where the video-generation scripts live (the `scripts/` folder in the app repo is the
  likely home) and where the sample photos go in each repo.
- The exact video sizes, compression and poster images for the website. Keep the
  files small enough for a hero video, and provide a still-image fallback where useful.
- How the UI test reaches each state (accessibility identifiers may need adding in the
  app; if so, keep that change separate and small).
- Branch names, and how the work is split into commits and PRs. The website PR stays
  unmerged until 3.0.0 ships.
