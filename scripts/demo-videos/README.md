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
   or so are the home screen while the app installs; the HyperFrames compositions cut that out.

The storyboard test is skipped under the normal `multiborder` scheme. The `DemoRecording`
scheme sets `DEMO_RECORDING=1`, and the app's `-demoRecording` launch argument hides What's
New and tips and resets the border settings.

## 2. Render the videos (`render.sh`)

```sh
./scripts/demo-videos/render.sh
```

This uses the HyperFrames compositions in `hyperframes/` to turn `raw.mov` and the sample
photos into:

| File | Use |
|---|---|
| `app-store-preview.mp4` | App Store Connect (886×1920, 30 fps, 15–30s, silent stereo AAC) |
| `hero-demo.mp4` | The website's phone mockup (`public/demo.mp4`) |
| `border-styles.mp4/.jpg` | The website's "Borders your way" spotlight and its poster |
| `camera-caption.mp4/.jpg` | The website's "Camera settings caption" spotlight and its poster |

If the app's UI changes, record again first. The cut points in
`hyperframes/compositions/app-store-preview.html` may then need moving.
