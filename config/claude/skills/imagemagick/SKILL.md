---
name: imagemagick
description: >
  ImageMagick (magick) for image conversion, resizing, compression, cropping, rotating, watermarking, format conversion (WebP/AVIF/PNG/JPG/ICO), favicon and thumbnail generation, PDF handling, and batch processing.
  Use any time an image is converted, resized, compressed, cropped, watermarked, or turned into a favicon or thumbnail from the command line.
---

ImageMagick 7 ships the `magick` command. Legacy `convert`/`mogrify` still work but emit deprecation warnings on v7 — prefer `magick` and `magick mogrify`.

## Common Operations

### Convert Format

```bash
# Single conversion (format inferred from extension)
magick input.png output.jpg

# PNG -> WebP (lossy, quality 80)
magick input.png -quality 80 output.webp

# PNG -> WebP (lossless)
magick input.png -define webp:lossless=true output.webp

# Any -> AVIF (best compression for web)
magick input.png -quality 50 output.avif

# JPG -> PNG (preserve transparency target)
magick input.jpg output.png
```

### Resize / Scale

```bash
# Resize to exact width, keep aspect ratio
magick input.jpg -resize 800x output.jpg

# Resize to fit within box (no upscaling with >)
magick input.jpg -resize 1920x1080\> output.jpg

# Resize by percentage
magick input.jpg -resize 50% output.jpg

# Force exact dimensions (ignore aspect ratio)
magick input.jpg -resize 800x600! output.jpg

# Fill + crop to exact size (cover)
magick input.jpg -resize 800x600^ -gravity center -extent 800x600 output.jpg
```

### Compress / Optimize

```bash
# JPG: quality + strip metadata
magick input.jpg -strip -quality 82 -interlace JPEG output.jpg

# PNG: max lossless compression
magick input.png -strip -define png:compression-level=9 output.png

# PNG: lossy quantization (fewer colors, smaller file)
magick input.png -strip -colors 256 -depth 8 output.png

# Strip ALL metadata (EXIF, GPS, color profile)
magick input.jpg -strip output.jpg
```

### Crop

```bash
# Crop region WxH+X+Y (offset from top-left)
magick input.jpg -crop 400x300+50+50 +repage output.jpg

# Center crop to square
magick input.jpg -gravity center -extent 500x500 output.jpg

# Trim surrounding solid border
magick input.png -trim +repage output.png
```

### Rotate / Flip

```bash
magick input.jpg -rotate 90 output.jpg
magick input.jpg -flip output.jpg          # vertical
magick input.jpg -flop output.jpg          # horizontal
magick input.jpg -auto-orient output.jpg   # honor EXIF orientation
```

### Watermark

```bash
# Image overlay, bottom-right with 10px margin
magick input.jpg watermark.png -gravity southeast -geometry +10+10 -composite output.jpg

# Image overlay with opacity
magick input.jpg \( watermark.png -alpha set -channel A -evaluate multiply 0.4 \) \
  -gravity center -composite output.jpg

# Text watermark
magick input.jpg -gravity southeast -pointsize 36 -fill 'rgba(255,255,255,0.6)' \
  -annotate +20+20 'COPYRIGHT' output.jpg
```

### Thumbnails

```bash
# Fast thumbnail (strips profiles, optimized)
magick input.jpg -thumbnail 200x200 output.jpg

# Square thumbnail, center-cropped
magick input.jpg -thumbnail 200x200^ -gravity center -extent 200x200 thumb.jpg
```

### Favicon (multi-resolution ICO)

```bash
# Single source -> multi-size .ico (16/32/48)
magick input.png -define icon:auto-resize=16,32,48 favicon.ico

# Apple touch icon
magick input.png -resize 180x180 apple-touch-icon.png
```

### PDF

PDF read/write needs Ghostscript (`brew install ghostscript`). Without it ImageMagick fails with `no decode delegate for this image format PDF`.

```bash
# Images -> single PDF
magick page1.jpg page2.jpg page3.jpg output.pdf

# PDF -> PNG per page (150 DPI)
magick -density 150 input.pdf -quality 90 page-%03d.png

# PDF -> single combined JPG
magick -density 150 input.pdf -append output.jpg
```

### Transparency / Background

```bash
# Make white background transparent
magick input.png -fuzz 10% -transparent white output.png

# Flatten transparent onto white (for JPG)
magick input.png -background white -flatten output.jpg

# Replace background color
magick input.png -fuzz 15% -fill '#0d1117' -opaque white output.png
```

### Effects / Color

```bash
magick input.jpg -colorspace Gray output.jpg          # grayscale
magick input.jpg -blur 0x8 output.jpg                 # gaussian blur
magick input.jpg -modulate 100,120,100 output.jpg     # +20% saturation
magick input.jpg -brightness-contrast 10x15 output.jpg
magick input.jpg -level 5%,95% output.jpg             # contrast stretch
```

### Combine / Montage

```bash
# Horizontal append
magick a.jpg b.jpg +append row.jpg

# Vertical append
magick a.jpg b.jpg -append col.jpg

# Contact sheet grid with labels
magick montage *.jpg -tile 4x -geometry 200x200+5+5 contact.jpg
```

### Batch Processing

```bash
# Convert all PNG to WebP (in place naming)
for f in *.png; do magick "$f" -quality 80 "${f%.png}.webp"; done

# mogrify edits in place (CAREFUL: overwrites) — resize whole folder
magick mogrify -resize 1200x -quality 85 *.jpg

# Safe batch into subfolder
mkdir -p out && magick mogrify -path out -resize 1200x -format webp *.jpg
```

### Inspect

```bash
magick identify input.jpg                              # format, dimensions, depth
magick identify -verbose input.jpg | head -40          # full metadata
magick identify -format '%wx%h %[size]\n' input.jpg    # custom format
```

## Rules

- v7 syntax: `magick ...`. Don't mix with v6 `convert` unless on legacy.
- `-strip` on web exports — removes EXIF/GPS/profiles, smaller + privacy-safe.
- WebP for web photos, AVIF for best ratio, PNG only when transparency or lossless needed.
- `+repage` after `-crop` to reset virtual canvas, else offsets persist.
- `^` = fill (cover), `!` = force, `>` = shrink-only. Pick deliberately.
- `magick mogrify` overwrites originals — always `-path` to a separate dir for safety.
- High `-density` BEFORE the PDF input for crisp rasterization, not after.
