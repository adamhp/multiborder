# Demo videos

The App Store preview, the website's hero demo and the two website spotlight loops are all
generated from this folder. The output goes to `build/demo-videos/`, which git ignores.

## 1. Record the app (`record.sh`)

```sh
./scripts/demo-videos/record.sh
```

The script runs from a normal terminal, and it needs Xcode and the iOS 26.5 Simulator runtime.
It does the following:

1. Creates (once) and erases a "Multiborder Demo" Simulator (iPhone 17 Pro Max, iOS 26.5).
2. Loads `sample-photos/` into the Simulator, pre-grants photo saving and sets a 9:41 status bar.
3. Records the screen while the `DemoRecording` scheme plays the storyboard in
   `multiborderUITests/DemoRecordingUITests.swift`.
4. Writes `build/demo-videos/raw.mov`. The file is about 90 seconds long. The first 30 seconds
   or so are the home screen while the app installs; `cuts.py` cuts that out.

The storyboard test is skipped under the normal `multiborder` scheme. The `DemoRecording`
scheme sets `DEMO_RECORDING=1`, and the app's `-demoRecording` launch argument hides What's
New and tips and resets the border settings.

## 2. Capture the App Store screenshots (`screenshots.sh`)

```sh
./scripts/demo-videos/screenshots.sh
```

On a freshly erased demo Simulator (set up by `prepare-simulator.sh`, shared with `record.sh`), the
`AppStoreScreenshots` scheme runs `DemoRecordingUITests.testScreenshots`. It drives the app to each
of the ten screens, including editing a photo with the extension inside the Photos app, and
`build/demo-videos/shots-raw/NN-name.png` collects them at 1320×2868. `render.sh` then frames them.

## 3. Render the videos and screenshots (`render.sh`)

```sh
./scripts/demo-videos/render.sh
```

`cuts.py` first trims `raw.mov` to the storyboard's active moments at 1.18× speed (`cut.mp4`).
Then the HyperFrames compositions in `hyperframes/` turn that and the sample photos into:

| File | Use |
|---|---|
| `app-store-preview.mp4` | App Store Connect (886×1920, 30 fps, 15–30s, H.264 High Profile Level 4.0 at about 11 Mbps, silent 256 kbps stereo AAC) |
| `hero-demo.mp4` | The website's phone mockup (`public/demo.mp4`) |
| `border-styles.mp4/.jpg` | The website's "Borders your way" spotlight and its poster |
| `camera-caption.mp4/.jpg` | The website's "Camera settings caption" spotlight and its poster |
| `screenshots/NN-name.png` | App Store Connect, iPhone with Dynamic Island (large display) screenshots (1320×2868, opaque RGB), each under its headline from `hyperframes/compositions/app-store-screenshots.html` |
| `screenshots-medium/NN-name.png` | The same set for iPhone with Dynamic Island (medium display), 1206×2622, which App Store Connect requires |
| `app-store-header.png` | App Store creative asset for iOS 27+: one universal 16:9 image (5244×2950 PNG) that App Store Connect crops for the product page header (21:9) and search results (3:2), from `hyperframes/compositions/app-store-header.html` |

If the app's UI changes, record again first. A new take has different timings, so `cuts.py`
refuses to run until you update it:

1. List the frame times with `ffprobe -select_streams v:0 -show_entries frame=pts_time build/demo-videos/raw.mov`.
   The recording only writes a frame when the screen changes, so gaps are where nothing happens.
2. Update `SEGMENTS` (and `TAKE_DURATION`) in `cuts.py` to the new active spans.
3. Run `python3 scripts/demo-videos/cuts.py`, and copy the beat starts it prints into the captions'
   `data-start`/`data-duration` and the `beats` list in `hyperframes/compositions/app-store-preview.html`,
   plus the total into both compositions' `data-duration`.
