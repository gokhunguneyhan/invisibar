# nobar

Hide the iOS status bar for screen recordings. Also removes the red recording
indicator.

A Claude Code skill that adds one debug-only toggle to a SwiftUI app. Flip it, record
your screen, and the footage comes out with no clock, no battery, no carrier — **and
no red screen-recording indicator on the Dynamic Island.**

That last part is the surprise. The indicator is drawn by SpringBoard, not your app,
so the reasonable assumption is that an app-level modifier can't touch it. It can:

| While screen recording | Toggle off | Toggle on |
|---|---|---|
| Time | 20:46 | gone |
| Signal / carrier / battery | shown | gone |
| Red dot on the Dynamic Island | shown, with red island outline | **gone** |

Verified on iPhone 17 Pro, iOS 26. Worth re-checking on new iOS majors rather than
trusting this table forever.

## Why

Marketing footage shot across several sessions has a different clock and a different
battery in every clip, and every frame is stamped with a recording indicator. Apple's
own material shows 9:41 and a full battery throughout. This gets you a clean top edge
to work from, and optionally a consistent status bar composited back on top.

## Install

```bash
git clone https://github.com/YOURNAME/nobar
cp -r nobar ~/.claude/skills/
```

Then ask Claude Code, in the repo of the app you want it in:

> add a recording mode toggle for clean screen recordings

Per-project instead of global: copy into `.claude/skills/` inside the project.

## What it writes

Three small edits, none of them app-specific:

```swift
// 1. The flag. The whole TYPE behind #if DEBUG, not just its value.
#if DEBUG
enum RecordingMode { static let key = "recordingModeEnabled" }
#endif

// 2. Read it at the outermost view, above every early return.
var body: some View {
    content.statusBarHidden(hideStatusBarForCapture)
}

// 3. A toggle beside the app's existing debug switches.
```

Plus the verification to prove the flag can't reach a shipping build.

## The two bugs it exists to prevent

Both were made on a real implementation, and both looked correct in review.

**Gating the value instead of the type.** Leave the UserDefaults key outside the
`#if DEBUG` with an unconditional `@AppStorage` reading it, and the Release binary
contains the key — the shipping build genuinely reads it and would hide the status
bar if anything set it. `strings` on the Release binary finds it twice.

**Applying the modifier below an early return.** If `body` returns early for any
branch — a launch argument, a loading state, a separate onboarding root — a modifier
applied further in silently misses those screens. In the original case that was the
one staged screen most likely to be recorded, and the before/after screenshots were
byte-identical across the top 1840 rows.

## Verification that doesn't fool you

`references/verify.md` is most of the value here. Every check has a way of passing for
the wrong reason:

- **`strings` needs a control.** A clean zero is also what a typo gives you. Check a
  key you know ships, in the same command.
- **The Debug binary is a stub.** Xcode puts the code in `App.debug.dylib` beside a
  ~58 KB launcher, so `strings App.app/App` returns nothing for everything and every
  check "passes".
- **A flat cross-correlation curve means your two screenshots are identical**, not
  that layout is stable. Confirm the status bar region actually differs first.
- **The simulator can't test the recording indicator at all.** `simctl io recordVideo`
  never draws one, so a simulator capture proves nothing either way.

## Optional: put a status bar back

Only if you want one visible in the final video. Most App Previews have no status bar
and look fine.

```bash
python3 tools/make_status_bar.py --width 1206 --height 2622 --time 9:41 --out bar.png
```

![The generated overlay on a checkerboard, showing the transparent background](assets/overlay_on_checkerboard.png)

Writes a transparent PNG — only glyph pixels have alpha, ~3% of the strip — to drop on
a track above your footage, top-left, no scaling. Geometry is measured, not guessed:
the generated cluster lands within 1px of the real thing on the reference device.

It can't restore the frosted backdrop, because hiding the bar takes the glass with it
and no flat PNG can blur what's beneath it. If you want that look, blur a duplicate
layer in your editor and mask it to the top strip. `references/overlay.md` covers it,
along with the ffmpeg route and the App Preview resolution requirement that rejects
native-resolution uploads.

## Cheaper option, no code

If you have a Mac and a cable, QuickTime already does this: File → New Movie
Recording, pick the iPhone as **both** camera and microphone. It substitutes 9:41 with
a full battery and no carrier, and there's no recording indicator because the capture
happens on the Mac. The status bar is real, so its backdrop is real and reacts to
content for free.

This skill is for capture on the phone alone. It says so up front, and tells Claude to
mention QuickTime before writing any code.

## Requirements

SwiftUI, any iOS version with `.statusBarHidden(_:)`. The generator needs Python 3 and
Pillow, and uses SF Pro from macOS by default (`--font` to point elsewhere).

## License

MIT
