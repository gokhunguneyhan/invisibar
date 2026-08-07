#!/usr/bin/env python3
"""Generate a transparent iOS status bar overlay PNG for screen recordings.

Only useful together with the in-app recording-mode toggle (see SKILL.md), which
hides the real status bar. With the bar hidden your footage has a clean top edge
and no screen-recording indicator; this draws a consistent time and battery back
on top in your video editor, the way Apple's own marketing footage shows 9:41.

The output is RGBA with a fully transparent background: only glyph pixels have
alpha. Nothing is washed or boxed, so whatever the app draws underneath survives
untouched.

    python3 make_status_bar.py --width 1206 --out bar.png
    python3 make_status_bar.py --width 1206 --height 2622 --time 9:41 --out bar.png

CALIBRATION. Defaults are measured, not guessed, from two 1206x2622 captures of a
402pt-wide 3x device (iPhone 17 Pro, iOS 26). See METRICS below for what came from
where. Two things worth knowing before trusting them on another device:

  * The vertical band was IDENTICAL in both a simulator and a device capture
    (26.7-38.3pt), which makes it the most reliable number here.
  * Horizontal positions are not stable across states. In a capture taken while
    screen recording, the Dynamic Island is expanded, which pushes the time left:
    centre 61.5pt recording vs 74.2pt idle. The idle value is the default, because
    that is the layout you are reproducing.

Check the result against a real screenshot of the same device at 200% before
shooting a lot of footage, and nudge with --time-x / --right-inset if needed.

Requires Pillow. The time is set in SF Pro, which ships with macOS; pass
--font to point at a TTF on other platforms.
"""

import argparse
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is required:  python3 -m pip install pillow")


# All values in points. Multiply by the device scale factor for pixels.
METRICS = {
    # Measured: glyph tops/bottoms at y 26.7-38.3pt, consistent across captures.
    "band_top": 26.7,
    "band_bottom": 38.3,
    # Measured idle (not recording): time spanned 53.0-95.3pt, centre 74.2pt.
    "time_centre_x": 74.2,
    "time_size": 17.0,
    # Measured: battery nub right edge at 370.7pt on a 402pt-wide screen.
    "right_inset": 31.3,
    # Apple's published Dynamic Island size. Measured 125.3 x 36.7pt at top 14pt,
    # centred to within half a pixel, which is why the ratio should generalise.
    "island_w": 125.0,
    "island_h": 36.7,
    "island_top": 14.0,
    # Battery: Apple's standard 25 x 12pt body with a small nub.
    "batt_w": 25.0,
    "batt_h": 12.0,
    "batt_radius": 3.8,
    "batt_nub_w": 1.6,
    "batt_nub_h": 4.2,
    "batt_stroke": 1.0,
    # Signal: four bars, tallest last.
    "bar_w": 3.0,
    "bar_gap": 1.7,
    "bar_heights": [4.0, 6.3, 8.7, 11.3],
    "wifi_w": 17.0,
    # Tuned, not derived: 5.5pt put the cluster's left edge 8px wide of the real
    # one on the reference capture. 4.2pt lands it within a pixel.
    "gap": 4.2,           # between right-cluster elements
    "label_size": 14.0,   # "5G" / "LTE"
}


def rounded_rect(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)


def draw_time(draw, m, s, text, font, colour, centre_x):
    cy = (m["band_top"] + m["band_bottom"]) / 2 * s
    draw.text((centre_x * s, cy), text, font=font, fill=colour, anchor="mm")


def draw_signal(draw, m, s, x_right, colour):
    """Four bars, bottom-aligned to the glyph band. Returns the left edge."""
    bottom = m["band_bottom"] * s
    w, gap = m["bar_w"] * s, m["bar_gap"] * s
    n = len(m["bar_heights"])
    total = n * w + (n - 1) * gap
    x = x_right - total
    left = x
    for h_pt in m["bar_heights"]:
        h = h_pt * s
        rounded_rect(draw, [x, bottom - h, x + w, bottom],
                     radius=max(1, 0.8 * s), fill=colour)
        x += w + gap
    return left


def draw_wifi(draw, m, s, x_right, colour):
    """Three arcs and a dot. Returns the left edge."""
    w = m["wifi_w"] * s
    left = x_right - w
    cx = x_right - w / 2
    bottom = m["band_bottom"] * s
    stroke = max(1, int(round(1.6 * s)))
    # Dot at the apex of the fan.
    r = 1.5 * s
    draw.ellipse([cx - r, bottom - r * 2, cx + r, bottom], fill=colour)
    for i, rad_pt in enumerate((4.4, 7.4, 10.4)):
        rad = rad_pt * s
        box = [cx - rad, bottom - rad, cx + rad, bottom + rad]
        draw.arc(box, start=218, end=322, fill=colour, width=stroke)
    return left


def draw_label(draw, m, s, x_right, text, font, colour):
    """'5G' / 'LTE'. Returns the left edge."""
    cy = (m["band_top"] + m["band_bottom"]) / 2 * s
    box = draw.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    draw.text((x_right, cy), text, font=font, fill=colour, anchor="rm")
    return x_right - w


def draw_battery(draw, m, s, x_right, percent, colour, charging):
    """Outline plus a fill proportional to `percent`. Returns the left edge."""
    nub_w, nub_h = m["batt_nub_w"] * s, m["batt_nub_h"] * s
    bw, bh = m["batt_w"] * s, m["batt_h"] * s
    cy = (m["band_top"] + m["band_bottom"]) / 2 * s
    nub_right = x_right
    body_right = nub_right - nub_w - 0.8 * s
    body_left = body_right - bw
    top, bottom = cy - bh / 2, cy + bh / 2

    # The nub and outline are translucent in iOS; the level fill is solid.
    faint = (*colour[:3], int(colour[3] * 0.38)) if len(colour) == 4 else colour
    rounded_rect(draw, [body_right + 0.8 * s, cy - nub_h / 2,
                        nub_right, cy + nub_h / 2],
                 radius=nub_w / 2, fill=faint)
    rounded_rect(draw, [body_left, top, body_right, bottom],
                 radius=m["batt_radius"] * s, outline=faint,
                 width=max(1, int(round(m["batt_stroke"] * s))))

    inset = m["batt_stroke"] * s + 1.0 * s
    avail = (body_right - inset) - (body_left + inset)
    frac = max(0.0, min(1.0, percent / 100.0))
    if frac > 0:
        rounded_rect(draw, [body_left + inset, top + inset,
                            body_left + inset + avail * frac, bottom - inset],
                     radius=max(1, 1.6 * s), fill=colour)
    if charging:
        # A small bolt sitting over the body, as iOS draws when plugged in.
        cx = (body_left + body_right) / 2
        h = bh * 0.78
        draw.polygon([(cx + 0.9 * s, cy - h / 2), (cx - 2.4 * s, cy + 0.8 * s),
                      (cx - 0.2 * s, cy + 0.8 * s), (cx - 1.1 * s, cy + h / 2),
                      (cx + 2.6 * s, cy - 1.0 * s), (cx + 0.4 * s, cy - 1.0 * s)],
                     fill=colour)
    return body_left


def load_font(path, size_px, weight="Semibold"):
    font = ImageFont.truetype(path, int(round(size_px)))
    try:
        font.set_variation_by_name(weight)
    except Exception:
        pass  # Static font, or no such named instance. Its default weight will do.
    return font


def main():
    p = argparse.ArgumentParser(
        description="Transparent iOS status bar overlay for screen recordings.")
    p.add_argument("--out", default="status_bar.png")
    p.add_argument("--width", type=int, required=True,
                   help="Frame width in PIXELS (e.g. 1206 for a 3x 402pt device).")
    p.add_argument("--height", type=int, default=None,
                   help="Canvas height in pixels. Default is the status bar strip "
                        "only. Pass the full frame height to get a full-frame "
                        "overlay you can drop in an editor without positioning.")
    p.add_argument("--scale", type=float, default=None,
                   help="Device scale factor. Default: inferred from --width "
                        "assuming a 402pt-wide screen; pass it explicitly for "
                        "any other device.")
    p.add_argument("--time", default="9:41")
    p.add_argument("--battery", type=float, default=100.0,
                   help="Battery level 0-100 (default 100).")
    p.add_argument("--charging", action="store_true")
    p.add_argument("--carrier", default="5G",
                   help="Label beside the signal bars. Empty string omits it.")
    p.add_argument("--no-signal", action="store_true")
    p.add_argument("--no-wifi", action="store_true")
    p.add_argument("--no-battery", action="store_true")
    p.add_argument("--dark", action="store_true",
                   help="Black glyphs, for light app backgrounds.")
    p.add_argument("--island-cover", action="store_true",
                   help="Opaque black pill over the Dynamic Island. NOT needed "
                        "when the app hid its status bar: that already removes "
                        "the red recording indicator. Only for footage captured "
                        "WITHOUT recording mode.")
    p.add_argument("--time-x", type=float, default=None,
                   help="Override the time's centre, in points.")
    p.add_argument("--right-inset", type=float, default=None,
                   help="Override the right margin, in points.")
    p.add_argument("--font", default="/System/Library/Fonts/SFNS.ttf")
    args = p.parse_args()

    m = dict(METRICS)
    s = args.scale if args.scale else args.width / 402.0
    if args.time_x is not None:
        m["time_centre_x"] = args.time_x
    if args.right_inset is not None:
        m["right_inset"] = args.right_inset

    if not os.path.exists(args.font):
        sys.exit(f"Font not found: {args.font}\n"
                 "Pass --font with a path to a TTF (SF Pro on macOS, or any "
                 "close sans-serif elsewhere).")

    strip_h = int(round(54 * s))       # status bar height on notch/island devices
    H = args.height if args.height else strip_h
    img = Image.new("RGBA", (args.width, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    colour = (0, 0, 0, 255) if args.dark else (255, 255, 255, 255)

    if args.island_cover:
        iw, ih = m["island_w"] * s, m["island_h"] * s
        x0 = (args.width - iw) / 2
        y0 = m["island_top"] * s
        rounded_rect(d, [x0, y0, x0 + iw, y0 + ih], radius=ih / 2,
                     fill=(0, 0, 0, 255))

    time_font = load_font(args.font, m["time_size"] * s)
    draw_time(d, m, s, args.time, time_font, colour, m["time_centre_x"])

    x = args.width - m["right_inset"] * s
    if not args.no_battery:
        x = draw_battery(d, m, s, x, args.battery, colour, args.charging) - m["gap"] * s
    if not args.no_wifi:
        x = draw_wifi(d, m, s, x, colour) - m["gap"] * s
    if args.carrier:
        label_font = load_font(args.font, m["label_size"] * s)
        x = draw_label(d, m, s, x, args.carrier, label_font, colour) - m["gap"] * s
    if not args.no_signal:
        x = draw_signal(d, m, s, x, colour) - m["gap"] * s

    img.save(args.out)
    opaque = sum(1 for a in img.getchannel("A").tobytes() if a > 0)
    print(f"wrote {args.out}  {img.size[0]}x{img.size[1]}  "
          f"scale {s:g}x  {opaque} opaque px "
          f"({100.0 * opaque / (img.size[0] * img.size[1]):.2f}% of canvas)")


if __name__ == "__main__":
    main()
