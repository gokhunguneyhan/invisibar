---
name: nobar
description: Add a debug-only toggle to a SwiftUI iOS app that hides the status bar for clean screen recordings, which also removes the red screen-recording indicator from the Dynamic Island. Use when the user wants consistent time and battery across marketing footage, App Preview or App Store video captures, or wants to record their own app without the recording indicator showing.
---

# nobar

A screen recording carries whatever the phone's status bar happened to say: 20:46, a
red low battery, and the red screen-recording indicator on the Dynamic Island. Across
a set of clips nothing matches, and the indicator marks every frame as a capture.

One `#if DEBUG` toggle fixes all of it. `.statusBarHidden(true)` removes the time,
battery, signal **and the recording indicator**, verified on a device below. Then, if
you want a status bar in the final video, composite a clean one in post.

**Do this first, before writing any code:** if the user has a Mac and a cable, tell
them about QuickTime (§Cheaper option). It solves the same problem with no code at
all. This skill is for capture on the phone alone.

---

## What to build

Three edits. The gating is the part that is easy to get wrong, so do it in this order
and verify with §Verify before saying it works.

### 1. The flag

The **whole type** goes behind `#if DEBUG`, not just its value:

```swift
#if DEBUG
enum RecordingMode {
    static let key = "recordingModeEnabled"
}
#endif
```

Gating only the value leaves a Release binary that reads the key and would hide the
status bar if anything ever set it. See §The mistake to avoid.

### 2. Read it at the root view

Both the stored property and the read are `#if DEBUG`, so Release has no path:

```swift
#if DEBUG
@AppStorage(RecordingMode.key) private var recordingMode = false
#endif

/// false at compile time in Release: the stored property does not exist there.
private var hideStatusBarForCapture: Bool {
    #if DEBUG
    recordingMode
    #else
    false
    #endif
}
```

Apply it at the **outermost** view the app ever shows:

```swift
var body: some View {
    content.statusBarHidden(hideStatusBarForCapture)
}
```

`@AppStorage` rather than a plain `static var` so the toggle takes effect the moment
it is flipped, with no relaunch.

**Where it goes matters more than it looks.** If `body` has any early return — a
launch-argument branch, a loading state, a separate onboarding root — a modifier
applied further in will silently miss those screens. Read the whole of `body` and
put it above every branch. This is the failure mode in §The mistake to avoid.

No hosting controller and no `prefersStatusBarHidden` override is needed. That advice
is for UIKit; in SwiftUI the modifier is the whole job.

### 3. The toggle

Beside whatever debug switches the app already has, inside their `#if DEBUG` block.
Match the surrounding style rather than introducing a new one. Two things to get
right:

- Bind straight to `@AppStorage(RecordingMode.key)`, so it and the root view observe
  the same key.
- Say in the subtitle what it does and that it is for capture, so it is not mistaken
  for a user setting during a later audit.

If the app has no debug section, put it behind whatever gate its other internal
tools use, and make sure that gate is compile-time or an admin check, never a plain
boolean a user could reach.

---

## Verify

Do not report this as working off a screenshot alone. Three checks, and each has a
way of passing for the wrong reason. `references/verify.md` has the full method and
the traps; the short version:

1. **The gate holds.** `strings -a` the Release binary for the key, **and for a
   control key you know is there.** A clean zero proves nothing on its own — a typo
   or the wrong binary gives the same answer.
2. **Layout does not shift.** Screenshot with the flag on and off and cross-correlate
   the content region. If the best alignment is not 0px, an overlay will not line up.
3. **It works on a device.** The simulator cannot test the recording indicator at
   all: `simctl io recordVideo` never draws one.

---

## The mistake to avoid

Both of these were made and caught on a real implementation, and both looked correct
in review:

**Gating the value instead of the type.** `RecordingMode.key` outside the `#if DEBUG`
with an unconditional `@AppStorage` reading it. It compiles, it looks DEBUG-only, and
`strings` on the Release binary finds the key twice — the shipping build really does
read it. Gate the type and neither call site compiles in Release.

**Applying the modifier below an early return.** `body` returned early for a
launch-argument branch, so `.statusBarHidden()` on the main body never reached that
screen — which happened to be the staged screen most likely to be recorded. The flag
did nothing there and the before/after screenshots were byte-identical across the top
1840 rows.

---

## Cheaper option, mention it first

QuickTime Player has substituted a clean status bar on wired iOS captures since OS X
Yosemite: 9:41, full signal, full Wi-Fi, full battery, no carrier. Same substitution
Apple's own marketing uses, and **no recording indicator**, because the capture
happens on the Mac.

1. Cable the iPhone to the Mac.
2. QuickTime Player, File, New Movie Recording.
3. Beside the record button, pick the iPhone as **both** camera and microphone.
4. Record.

The status bar is real, so its backdrop is real and reacts to content for free.
Nothing is synthesised, so nothing can fail to match. Verify on the first take that
the battery shows no charging bolt — it is cabled, so a bolt is plausible, and if it
appears this skill is the fallback.

A middle option with no code and no Mac: set the time manually (Settings, General,
Date & Time, Set Automatically off) and charge above ~30% so the battery is not red.
Turn automatic time back on afterwards or anything in the app that depends on the
clock will be wrong. This leaves the recording indicator, which is the thing only
recording mode and QuickTime remove.

---

## Optional: composite a status bar back

Only if the user wants a visible status bar in the final video, the way Apple's
marketing shows 9:41. Hiding the bar leaves a clean top edge, which is fine on its
own and what most App Previews have.

`tools/make_status_bar.py` writes a transparent PNG with time, signal, Wi-Fi and
battery. Drop it on a track above the footage in any editor, aligned top-left, no
scaling.

```bash
python3 tools/make_status_bar.py --width 1206 --out bar.png
python3 tools/make_status_bar.py --width 1206 --height 2622 --time 9:41 --battery 100 --out bar.png
```

Passing `--height` makes it full-frame, which is harder to misalign.

**It cannot restore a frosted backdrop.** Hiding the status bar takes its glass with
it, so content runs sharp to the top edge. A PNG cannot blur what is beneath it, and
one that tries reads as a milky wash. If the frosted look is wanted, blur a duplicate
of the footage in the editor and mask it to the top strip. `references/overlay.md`
covers that, the ffmpeg route, and the App Preview resolution requirement that
rejects native-resolution uploads.

Do **not** pass `--island-cover` for footage shot with recording mode on. There is no
indicator left to hide, and the cover would only paint black over black.
