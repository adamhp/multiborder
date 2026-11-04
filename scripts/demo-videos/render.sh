#!/bin/bash
# Renders the App Store preview, the website hero demo, the two website spotlight loops and (after
# screenshots.sh) the ten App Store screenshots into build/demo-videos/. Run from a normal terminal
# after record.sh:
#   ./scripts/demo-videos/render.sh
# Needs Node 22+, ffmpeg and network access the first time (HyperFrames, its headless Chrome,
# GSAP from jsDelivr).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="$repo/build/demo-videos"
hf="$here/hyperframes"
hyperframes="npx --yes hyperframes@0.8.179"

# 1. Cut the raw take down to the storyboard (build/demo-videos/cut.mp4).
python3 "$here/cuts.py" "$out"

# 2. Assets the compositions load (git-ignored copies).
mkdir -p "$hf/assets"
cp "$out/cut.mp4" "$hf/assets/cut.mp4"
ffmpeg -v error -y -i "$hf/assets/cut.mp4" -frames:v 1 -q:v 2 "$hf/assets/cut-first.jpg"
cp "$repo/Shared/SpaceMono.ttf" "$repo/Shared/DMMono-Regular.ttf" "$hf/assets/"
cp "$repo"/sample-photos/IMG_20{66,69,70,71,72}.JPG "$hf/assets/"

# 3. Render each composition at delivery quality. UI footage extracts as PNG to keep text crisp.
cd "$hf"
$hyperframes lint .
for name in app-store-preview hero-demo border-styles camera-caption; do
  $hyperframes render -c "compositions/$name.html" -o "renders/$name.mp4" \
    --quality delivery --fps 30 --video-frame-format png --quiet
done

# 4. Finish each file for where it goes.
# App Store: Apple's App Preview spec is H.264 up to High Profile Level 4.0 at a 10–12 Mbps target,
# with 256 kbps stereo AAC, so re-encode rather than copy the render (which comes out at Level 4.2).
ffmpeg -v error -y -i renders/app-store-preview.mp4 -f lavfi -i anullsrc=r=48000:cl=stereo -shortest \
  -c:v libx264 -profile:v high -level:v 4.0 -b:v 11M -maxrate 12M -bufsize 22M -pix_fmt yuv420p -r 30 \
  -c:a aac -b:a 256k -ar 48000 -movflags +faststart "$out/app-store-preview.mp4"
# Website: small silent H.264 files that start playing before they finish downloading.
# The hero demo plays 25% faster than the App Store preview; it loops in the background of the page.
ffmpeg -v error -y -i renders/hero-demo.mp4 -an -vf "setpts=PTS/1.25" -r 30 -c:v libx264 -preset slow -crf 26 \
  -pix_fmt yuv420p -movflags +faststart "$out/hero-demo.mp4"
for name in border-styles camera-caption; do
  ffmpeg -v error -y -i "renders/$name.mp4" -an -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p \
    -movflags +faststart "$out/$name.mp4"
  # The poster is what loads first and what reduced-motion visitors see, so take it where the
  # feature is fully showing (corners, shadow and deep border; the caption in DM Mono), not frame 0.
  ffmpeg -v error -y -ss 5.8 -i "$out/$name.mp4" -frames:v 1 -q:v 3 "$out/$name.jpg"
done

# App Store screenshots: frame each raw screenshot under its headline, one per second at 1 fps,
# then flatten to opaque RGB PNGs (App Store Connect rejects transparency) named like the raw ones.
if compgen -G "$out/shots-raw/[01][0-9]-*.png" >/dev/null; then
  mkdir -p "$hf/assets/shots" renders/shots "$out/screenshots"
  rm -f "$hf"/assets/shots/*.png renders/shots/*.png "$out"/screenshots/*.png
  cp "$out"/shots-raw/[01][0-9]-*.png "$hf/assets/shots/"
  $hyperframes render -c compositions/app-store-screenshots.html -o renders/shots \
    --format png-sequence --fps 1 --quiet
  frames=(renders/shots/*.png)
  i=0
  # App Store Connect requires the medium Dynamic Island iPhone size too (1206x2622), and fills it in
  # from the older Face ID size rather than from ours, so make that set as well. The two aspect ratios
  # differ by under 0.1%, so scaling the finished image doesn't visibly stretch anything.
  mkdir -p "$out/screenshots-medium"
  rm -f "$out"/screenshots-medium/*.png
  for shot in "$out"/shots-raw/[01][0-9]-*.png; do
    name="$(basename "$shot")"
    ffmpeg -v error -y -i "${frames[$i]}" -pix_fmt rgb24 "$out/screenshots/$name"
    ffmpeg -v error -y -i "${frames[$i]}" -vf "scale=1206:2622:flags=lanczos" -pix_fmt rgb24 \
      "$out/screenshots-medium/$name"
    i=$((i + 1))
  done
else
  echo "No raw screenshots in $out/shots-raw; run screenshots.sh to make the App Store screenshots."
fi

# App Store creative asset (iOS 27+): one universal 16:9 image, 5244x2950 PNG without alpha, which App
# Store Connect crops for both the product page header (21:9) and search results (3:2).
mkdir -p renders/header
rm -f renders/header/*.png
$hyperframes render -c compositions/app-store-header.html -o renders/header --format png-sequence --fps 1 --quiet
ffmpeg -v error -y -i "$(ls renders/header/*.png | head -1)" -pix_fmt rgb24 "$out/app-store-header.png"

# 5. Show what came out, to check against the limits in README.md.
for f in app-store-preview hero-demo border-styles camera-caption; do
  echo "== $f.mp4"
  ffprobe -v error -show_entries stream=codec_type,codec_name,profile,level,width,height,r_frame_rate,bit_rate,channels \
    -show_entries format=duration,size -of compact "$out/$f.mp4"
done
for f in "$out"/screenshots/*.png "$out"/screenshots-medium/*.png "$out/app-store-header.png"; do
  [ -e "$f" ] && echo "== $(basename "$(dirname "$f")")/$(basename "$f") $(ffprobe -v error -show_entries stream=width,height,pix_fmt -of csv=p=0 "$f")"
done
