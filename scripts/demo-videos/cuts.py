#!/usr/bin/env python3
"""Cuts build/demo-videos/raw.mov down to the storyboard's active moments.

The Simulator recording only writes a frame when the screen changes, so the gaps between
these spans are frozen frames (the UI test querying the out-of-process photo picker, or
holding still). Cutting them leaves no visible jump. Re-check the spans after a new take:
`ffprobe -select_streams v:0 -show_entries frame=pts_time raw.mov` lists the frame times.

Writes cut.mp4 (886x1920, 30 fps, no audio) and prints each beat's start in the cut, which
the HyperFrames composition uses to time its captions.
"""
import subprocess
import sys
from pathlib import Path

# (beat, source start, source end) in raw.mov seconds — take 3, 2026-11-03.
SEGMENTS = [
    ("select", 23.30, 24.10),   # first photo
    ("select", 35.95, 36.75),   # second
    ("select", 38.05, 38.85),   # third
    ("select", 40.15, 40.95),   # fourth
    ("select", 42.25, 44.60),   # Done, the card stack
    ("size", 45.15, 46.90),     # Edit tab
    ("size", 48.00, 51.80),     # border width, 1:1
    ("styles", 52.25, 53.70),   # rounded corners on
    ("styles", 54.30, 56.50),   # corner radius
    ("styles", 56.90, 58.30),   # shadow on
    ("styles", 59.00, 61.60),   # shadow strength
    ("caption", 62.60, 64.10),  # camera settings caption on
    ("caption", 64.45, 65.30),  # caption style popover
    ("caption", 66.90, 67.70),  # DM Mono
    ("caption", 68.25, 69.00),  # popover closed
    ("save", 70.10, 75.00),     # Export, Download, Saved
]

def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "build/demo-videos"
    raw, cut = out_dir / "raw.mov", out_dir / "cut.mp4"
    # Constant frame rate first: a frame in the variable-rate recording lasts until the next change,
    # so trimming before this would stretch a segment's last frame across the following gap.
    n = len(SEGMENTS)
    parts = [f"[0:v]fps=30,split={n}" + "".join(f"[s{i}]" for i in range(n))]
    for i, (_, start, end) in enumerate(SEGMENTS):
        parts.append(f"[s{i}]trim={start}:{end},setpts=PTS-STARTPTS[v{i}]")
    joined = "".join(f"[v{i}]" for i in range(len(SEGMENTS)))
    # 1320x2868 scales to 886x1925; crop the 5 spare rows to reach Apple's 886x1920.
    graph = ";".join(parts) + f";{joined}concat=n={len(SEGMENTS)}:v=1:a=0,scale=886:-2,crop=886:1920,format=yuv420p[out]"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(raw), "-filter_complex", graph, "-map", "[out]",
                    "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-r", "30", str(cut)], check=True)

    t, seen = 0.0, set()
    for beat, start, end in SEGMENTS:
        if beat not in seen:
            print(f"{beat}: {t:.2f}s")
            seen.add(beat)
        t += end - start
    print(f"total: {t:.2f}s")

if __name__ == "__main__":
    main()
