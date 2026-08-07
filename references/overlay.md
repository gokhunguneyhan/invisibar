# Compositing a status bar back

Optional. With recording mode on, footage has a clean top edge and no recording
indicator, and most App Previews ship exactly like that. Read this only if a visible
status bar is wanted in the final video.

---

## The generator

`tools/make_status_bar.py` writes an RGBA PNG where **only glyph pixels have alpha** —
about 3% of the strip. Everything underneath survives.

```bash
# Status bar strip only, at a 3x device's pixel width.
python3 tools/make_status_bar.py --width 1206 --out bar.png

# Full-frame, which is harder to misalign in an editor.
python3 tools/make_status_bar.py --width 1206 --height 2622 --out bar.png

# Match a device that shows no Wi-Fi glyph, at 40% battery.
python3 tools/make_status_bar.py --width 1206 --no-wifi --battery 40 --out bar.png

# Light app background.
python3 tools/make_status_bar.py --width 1206 --dark --out bar.png
```

Drop it on a track above the footage, aligned top-left, no scaling. If you scale it,
the 1pt battery outline will soften and read as blurry.

`--scale` matters on anything that is not a 402pt-wide 3x screen. The default infers
scale from `--width` assuming 402pt, so pass it explicitly otherwise:

```bash
python3 tools/make_status_bar.py --width 886 --scale 2.2035 --out bar.png
```

### Calibration, and how far to trust it

Measured from two 1206×2622 captures of a 402pt-wide 3x device on iOS 26:

| Element | Measured | Confidence |
|---|---|---|
| Glyph band, vertical | y 26.7–38.3pt | **High.** Identical in a simulator and a device capture. |
| Time centre, idle | x 74.2pt | Medium. Shifts with island state, see below. |
| Right margin to battery nub | 31.3pt | High. Identical in both captures. |
| Dynamic Island | 125.0 × 36.7pt, top 14pt, centred | **High.** Measured to within half a pixel of Apple's published size. |
| Inter-element gap | 4.2pt | Tuned by eye to land the cluster within 1px, not derived. |

Against the reference capture the generated cluster lands **+0px on the right edge,
+0px on the top, −1px on the left**. Verify against a screenshot of your own device at
200% before shooting a lot of footage, and nudge with `--time-x` / `--right-inset`.

**Do not calibrate against a capture taken while recording.** The Dynamic Island is
expanded in that state and pushes the time left: centre 61.5pt recording versus 74.2pt
idle, a 13pt error if you measure the wrong shot. The vertical band is unaffected,
which is part of why it is the number to trust.

**Do not pass `--island-cover` for footage shot with recording mode on.** There is no
indicator left to hide and the cover only paints black over black. It exists for
footage captured without recording mode, where a real red indicator needs covering.

---

## What a PNG cannot do

Hiding the status bar takes its glass backdrop with it, so content runs sharp to the
top edge. A flat PNG cannot blur what is beneath it, and any PNG that tries reads as a
milky wash over one background and invisible over another.

If the frosted look is wanted, the blur has to come from the compositor. In an editor:
duplicate the footage on a track above, blur it, mask it to the top strip. In ffmpeg:

```
crop=iw:186:0:0, gblur=sigma=18, eq=brightness=0.06:saturation=0.85
```

iOS's status bar treatment **lightens and desaturates** as well as blurring, which is
why brightness and saturation are there and not just a gaussian. Tune all three
against a device screenshot of the same screen at 200%, side by side.

Expect to re-tune per clip. Values that look right over dark content read as milky
over light content. If clips vary a lot, the honest options are per-clip constants or
no synthesised glass at all.

---

## If you deliver an App Preview

**Check Apple's current spec before encoding.** These requirements change, and the one
below is the state as of writing rather than a permanent truth. At that point App
Store Connect accepted exactly **886×1920** for portrait previews on 6.1"–6.9"
displays, and **rejected a native-resolution upload**: a 1206×2622 recording is not an
accepted size. Also H.264, 30 fps, 15–30 s, under 500 MB.

1206×2622 scaled to 886 wide gives 1926 tall, so crop 6px of height rather than pad.

### Order of operations

**Composite at source resolution, then scale once.** Patch offsets stay in the
coordinate space they were measured in, and the single scale keeps glyph edges clean.

### ffmpeg traps, each hit for real

- **`drawbox color=black` writes limited-range black**, Y=16, so RGB(16,16,16).
  Against a source whose black is (1,0,5) the box is plainly visible. Patch with a
  donor crop from adjacent pixels instead, or sample the actual surrounding colour.
- **Bound measurement windows generously.** A glyph that fills the scan window makes
  min/max return the window edges rather than the glyph. This produced a battery patch
  that erased half of the "5G" and left the battery's right end behind.
- **`-loop 1` on a PNG overlay input never terminates.** A still needs no loop;
  `overlay` repeats its last frame. This hung an encode past ten minutes.
- **Full versus limited range.** iOS captures are `color_range=pc`. Deliver limited:
  add `in_range=pc:out_range=tv` to the scale and tag `-color_range tv -colorspace
  bt709`, or the output lands as deprecated `yuvj420p`.

### Confirm what you are about to upload

```bash
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,pix_fmt,color_range \
        -show_entries format=duration,size -of default=noprint_wrappers=1 out.mp4
```

Wants `h264`, `886x1920`, `30/1`, `yuv420p`, `tv`, duration 15–30, size under 500 MB.

### Choosing what to patch, when you are patching real footage

Sample each region's luminance across 6 frames spanning the clip:

- **Variance under ~2** means the region is effectively constant. A donor crop from
  adjacent pixels is exact, with no blur to tune.
- **Variance near the frosted band's own** means content moves behind it. A flat patch
  visibly dies there. Take the donor crop from a clean region **at the same y**, so it
  is the same scroll row and varies with the content by construction.
