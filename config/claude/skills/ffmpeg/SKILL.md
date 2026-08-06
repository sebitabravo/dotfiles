---
name: ffmpeg
description: >
  FFmpeg commands for video/audio conversion, compression, trimming, merging, filters, subtitle handling, and batch processing.
  Use any time a video or audio file is converted, compressed, trimmed, merged, subtitled, or batch-processed from the command line.
---

## Common Operations

### Convert Video Format

```bash
# MP4 (H.264 + AAC)
ffmpeg -i input.mov -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k output.mp4

# WebM (VP9 + Opus)
ffmpeg -i input.mp4 -c:v libvpx-vp9 -crf 30 -b:v 0 -c:a libopus -b:a 128k output.webm

# MP4 (H.265/HEVC — smaller file)
ffmpeg -i input.mp4 -c:v libx265 -crf 28 -preset medium -c:a aac -b:a 128k output.mp4
```

### Compress Video

```bash
# Target size (approximate, 2-pass)
SIZE_MB=50
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 input.mp4)
BITRATE=$(echo "($SIZE_MB * 8192) / $DURATION" | bc)
ffmpeg -i input.mp4 -c:v libx264 -b:v ${BITRATE}k -pass 1 -an -f null /dev/null && \
ffmpeg -i input.mp4 -c:v libx264 -b:v ${BITRATE}k -pass 2 -c:a aac -b:a 128k output.mp4

# Quick compress (single pass, CRF)
ffmpeg -i input.mp4 -c:v libx264 -crf 28 -preset fast -c:a copy output.mp4
```

### Trim / Cut

```bash
# Fast cut (keyframe-accurate)
ffmpeg -ss 00:01:30 -i input.mp4 -to 00:03:00 -c copy output.mp4

# Precise cut (re-encode)
ffmpeg -i input.mp4 -ss 00:01:30 -to 00:03:00 -c:v libx264 -crf 23 -c:a aac output.mp4

# Remove first 10 seconds
ffmpeg -i input.mp4 -ss 00:00:10 -c copy output.mp4
```

### Merge / Concat

```bash
# Create file list
echo "file 'part1.mp4'" > list.txt
echo "file 'part2.mp4'" >> list.txt
echo "file 'part3.mp4'" >> list.txt

ffmpeg -f concat -safe 0 -i list.txt -c copy output.mp4
```

### Extract Audio

```bash
# Extract audio as MP3
ffmpeg -i video.mp4 -vn -c:a libmp3lame -b:a 320k audio.mp3

# Extract audio as AAC
ffmpeg -i video.mp4 -vn -c:a aac -b:a 256k audio.m4a

# Extract audio without re-encoding
ffmpeg -i video.mp4 -vn -c:a copy audio.aac
```

### Resize / Scale

```bash
# Scale to 1080p
ffmpeg -i input.mp4 -vf scale=1920:1080 -c:v libx264 -crf 23 output.mp4

# Scale to 720p
ffmpeg -i input.mp4 -vf scale=1280:720 -c:v libx264 -crf 23 output.mp4

# Scale maintaining aspect ratio
ffmpeg -i input.mp4 -vf scale=1280:-1 -c:v libx264 -crf 23 output.mp4
```

### Speed Change

```bash
# 2x speed (video + audio)
ffmpeg -i input.mp4 -filter_complex "[0:v]setpts=0.5*PTS[v];[0:a]atempo=2[a]" -map "[v]" -map "[a]" output.mp4

# 0.5x slow motion
ffmpeg -i input.mp4 -filter_complex "[0:v]setpts=2*PTS[v];[0:a]atempo=0.5[a]" -map "[v]" -map "[a]" output.mp4
```

### Add Subtitles

```bash
# Burn subtitles into video (hardcoded)
ffmpeg -i input.mp4 -vf subtitles=subtitle.srt -c:a copy output.mp4

# Add as track (soft)
ffmpeg -i input.mp4 -i subtitle.srt -c copy -c:s mov_text output.mp4
```

### Batch Processing

```bash
# Convert all MOV to MP4
for f in *.mov; do
  ffmpeg -i "$f" -c:v libx264 -crf 23 -c:a aac -b:a 128k "${f%.mov}.mp4"
done

# Convert all to 720p
for f in *.mp4; do
  ffmpeg -i "$f" -vf scale=1280:720 -c:v libx264 -crf 23 -c:a copy "720p_${f}"
done
```

### Watermark

```bash
# Top-right corner
ffmpeg -i input.mp4 -i watermark.png -filter_complex "overlay=W-w-10:10" -c:a copy output.mp4

# Center with opacity
ffmpeg -i input.mp4 -i watermark.png -filter_complex "[1]format=rgba,colorchannelmixer=aa=0.5[wm];[0][wm]overlay=(W-w)/2:(H-h)/2" output.mp4
```

### GIF from Video

```bash
# Optimized GIF
ffmpeg -i input.mp4 -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" output.gif
```

### Record Screen (macOS)

```bash
# Capture display
ffmpeg -f avfoundation -i "1" -r 30 -c:v libx264 -crf 0 capture.mp4

# Capture with audio
ffmpeg -f avfoundation -i "1:0" -r 30 -c:v libx264 -crf 0 -c:a aac capture.mp4
```

## Useful Filters

```bash
# Denoise
ffmpeg -i input.mp4 -vf hqdn3d=4:3:6:4.5 output.mp4

# Sharpen
ffmpeg -i input.mp4 -vf unsharp=5:5:1.0:5:5:0.0 output.mp4

# Fade in/out
ffmpeg -i input.mp4 -vf "fade=t=in:st=0:d=2,fade=t=out:st=28:d=2" output.mp4

# Reverse video
ffmpeg -i input.mp4 -vf reverse -af areverse output.mp4

# Thumbnail grid
ffmpeg -i input.mp4 -vf "select='not(mod(n,30))',scale=160:90,tile=5x5" -frames:v 1 grid.png
```

## Rules

- `-c copy` when possible (no re-encode = instant + no quality loss).
- CRF 18-28 for H.264 (18 = near lossless, 28 = smaller file).
- 2-pass encoding for target file size.
- `-preset slower` for better compression, `-preset fast` for speed.
- `ffprobe` to inspect before processing.
- Always specify `-c:a` explicitly. Default varies by format.
- `-movflags +faststart` for web-playable MP4s.
