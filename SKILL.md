---
name: invisibar
description: Add a debug-only toggle to a SwiftUI iOS app that hides the status bar for clean screen recordings, which also removes the red screen-recording indicator from the Dynamic Island. Use when the user wants consistent time and battery across marketing footage, App Preview or App Store video captures, or wants to record their own app without the recording indicator showing.
---

# invisibar

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

`Invisibar.swift` in this repo is the whole thing. Copy it into the project and add
two call sites — do not retype it from memory.

```bash
cp <skill-dir>/Invisibar.swift <project>/Sources/
```

**1. The modifier, at the outermost view the app shows:**

```swift
WindowGroup { RootView().invisibar() }
```

**2. The footnote, anywhere it can sit quietly** — under a settings list is ideal,
because a small scroll takes it out of frame:

```swift
InvisibarLink()
```

That is the entire integration. Do not build a settings card, a toggle row, or a
separate screen: the footnote is deliberately small so it can be moved out of shot,
and a card cannot be.

If the project uses a generated Xcode project (xcodegen, Tuist), regenerate after
copying the file in or the build fails on a missing input.

### The one thing to get right

Apply `.invisibar()` **above every early return** in the root `body`. If `body`
returns early for a launch argument, a loading state, or a separate onboarding root,
a modifier applied inside one branch silently misses the others. Read the whole of
`body` before choosing where it goes. See §The mistake to avoid.

### How it is gated

For a file people paste into their own app, the API must exist in Release or their
call sites will not compile. So it is gated by *behaviour*, not by the type:

- `InvisibarLink` renders `EmptyView` in Release.
- `.invisibar()` returns the view untouched in Release.
- Everything with behaviour — the mode enum, the sheet, the drawn bar, the
  UserDefaults key — is inside `#if DEBUG` and does not exist in a Release build.

The type names survive as metadata. That is expected and carries nothing.

**This differs from gating an app-internal flag**, where you should put the whole
type behind `#if DEBUG` so nothing exists at all. Both are correct for their case;
the difference is whether anyone outside your target has to compile against it.

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

Both were made on a real implementation, and both looked correct in review.

**Gating the value instead of the type.** In an app-internal version, the UserDefaults
key sat outside `#if DEBUG` with an unconditional `@AppStorage` reading it. It
compiles, it looks DEBUG-only, and `strings` on the Release binary finds the key
twice — the shipping build really does read it and would hide the status bar if
anything set it.

**Applying the modifier below an early return.** The root `body` returned early for a
launch-argument branch, so the modifier never reached that screen — which happened to
be the staged screen most likely to be recorded. The flag did nothing there, and the
before/after screenshots were byte-identical across the top 1840 rows.

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

## If they want a status bar visible, not just gone

Two routes, and the in-app one is almost always better.

**Replace mode**, in the sheet. Draws a clean 9:41 and a full battery live, so what
you record is already finished and there is no editing step. Geometry is measured
from real captures and lands within 1–2px of the real bar on the reference device.
Check it against a screenshot of the user's own device before they shoot a lot of
footage.

**A PNG overlay**, via `tools/make_status_bar.py`, for editing after the fact — useful
when the time or battery needs to change without re-recording, or when footage was
already captured in hide mode. `references/overlay.md` covers it, along with the
ffmpeg route and the App Preview resolution requirement that rejects
native-resolution uploads.

Neither can restore the frosted backdrop. Hiding the status bar takes its glass with
it, so content runs sharp to the top edge. If that look is wanted, blur a duplicate
layer in the editor and mask it to the top strip.
