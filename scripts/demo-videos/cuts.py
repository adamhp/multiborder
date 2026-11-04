#!/usr/bin/env python3
"""Cuts build/demo-videos/raw.mov down to the storyboard's active moments.

The Simulator recording only writes a frame when the screen changes, so the gaps between
these spans are frozen frames (the UI test querying the out-of-process photo picker, or
holding still). Cutting them leaves no visible jump. Re-check the spans after a new take:
`ffprobe -select_streams v:0 -show_entries frame=pts_time raw.mov` lists the frame times.

Writes cut.mp4 (886x1920, 30 fps, no audio) and prints each beat's start in the cut. Those starts
are the caption times in hyperframes/compositions/app-store-preview.html; copy them across whenever
the spans or SPEED change.
"""
import re
import subprocess
import sys
from pathlib import Path

# (beat, source start, source end, hold) in raw.mov seconds — take 3, 2026-11-03. `hold` repeats the
# segment's last frame for that many seconds of output, so a short beat stays on screen long enough
# to read its caption.
TAKE_DURATION = 77.44  # raw.mov's length for this take; a new take needs new spans
SEGMENTS = [
    ("select", 23.30, 24.10, 0),   # first photo
    ("select", 35.95, 36.75, 0),   # second
    ("select", 38.05, 38.85, 0),   # third
    ("select", 40.15, 40.95, 0),   # fourth
    ("select", 42.25, 44.60, 0),   # Done, the card stack
    ("size", 45.15, 46.90, 0),     # Edit tab
    ("size", 48.00, 51.80, 0),     # border width, 1:1
    ("styles", 52.25, 53.70, 0),   # rounded corners on
    ("styles", 54.30, 56.50, 0),   # corner radius
    ("styles", 56.90, 58.30, 0),   # shadow on
    ("styles", 59.00, 61.60, 0),   # shadow strength
    ("caption", 62.60, 64.40, 1.0),  # camera settings caption on (ends before the font popover)
    ("save", 70.10, 75.00, 0),     # Export, Download, Saved
]
# Every interaction plays this much faster than it was recorded.
SPEED = 1.18


def duration(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         check=True, capture_output=True, text=True).stdout
    return float(out.strip())


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "build/demo-videos"
    raw, cut = out_dir / "raw.mov", out_dir / "cut.mp4"
    if abs(duration(raw) - TAKE_DURATION) > 0.5:
        sys.exit(f"{raw} is {duration(raw):.2f}s, not the {TAKE_DURATION}s take these spans were measured on.\n"
                 "Re-find the spans (see this file's docstring), update SEGMENTS and TAKE_DURATION, then copy the\n"
                 "printed beat starts into hyperframes/compositions/app-store-preview.html.")

    # Constant frame rate first: a frame in the variable-rate recording lasts until the next change,
    # so trimming before this would stretch a segment's last frame across the following gap.
    n = len(SEGMENTS)
    parts = [f"[0:v]fps=30,split={n}" + "".join(f"[s{i}]" for i in range(n))]
    for i, (_, start, end, hold) in enumerate(SEGMENTS):
        chain = f"[s{i}]trim={start}:{end},setpts=(PTS-STARTPTS)/{SPEED}"
        if hold:
            chain += f",tpad=stop_mode=clone:stop_duration={hold}"
        parts.append(chain + f"[v{i}]")
    joined = "".join(f"[v{i}]" for i in range(n))
    # Back to 30 fps after the speed-up; 1320x2868 scales to 886x1925, so crop the 5 spare rows
    # to reach Apple's 886x1920.
    graph = ";".join(parts) + f";{joined}concat=n={n}:v=1:a=0,fps=30,scale=886:-2,crop=886:1920,format=yuv420p[out]"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(raw), "-filter_complex", graph, "-map", "[out]",
                    # A keyframe every second: HyperFrames seeks the footage frame by frame, and sparse
                    # keyframes make those seeks freeze.
                    "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-r", "30", "-g", "30", "-keyint_min", "30",
                    str(cut)], check=True)

    # Beat starts from each segment's real frame count: every segment rounds to whole frames, so
    # adding up the spans' lengths drifts by a few frames over the cut.
    frames, seen = 0, set()
    for beat, start, end, hold in SEGMENTS:
        if beat not in seen:
            print(f"{beat}: {frames / 30:.2f}s")
            seen.add(beat)
        chain = f"fps=30,trim={start}:{end},setpts=(PTS-STARTPTS)/{SPEED}"
        if hold:
            chain += f",tpad=stop_mode=clone:stop_duration={hold}"
        probe = subprocess.run(["ffmpeg", "-v", "error", "-i", str(raw), "-vf", chain + ",fps=30", "-f", "null", "-",
                                "-progress", "pipe:1"], check=True, capture_output=True, text=True).stdout
        frames += int(re.findall(r"frame=(\d+)", probe)[-1])
    print(f"total: {frames / 30:.2f}s (cut.mp4 is {duration(cut):.2f}s)")

if __name__ == "__main__":
    main()
