# Verifying recording mode

Three claims to prove: the flag cannot exist in a shipping build, layout does not
shift when the bar hides, and the thing works on a device. Each has a way of passing
for the wrong reason, which is the only reason this file is long.

---

## 1. The gate holds

The claim is that a Release binary has no path to enable recording mode. Test it on
the binary, not the source.

```bash
xcodebuild -project App.xcodeproj -scheme App -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/dd-release build

BIN=/tmp/dd-release/Build/Products/Release-iphonesimulator/App.app/App
strings -a "$BIN" | grep -c recordingModeEnabled     # want 0
```

### Always use a control string

Zero is also what you get from a typo, the wrong path, or a `strings` invocation that
reads nothing. Check a key you **know** ships, in the same command:

```bash
for s in recordingModeEnabled someKeyThatDefinitelyShips; do
  printf '%-32s %s\n' "$s" "$(strings -a "$BIN" | grep -c "$s")"
done
```

A real result looks like this. The control being non-zero is what makes the zero
meaningful:

| String | Debug | Release |
|---|---|---|
| `recordingModeEnabled` | 1 | **0** |
| `didRepairPermissions` (control) | 1 | 2 |

### The Debug binary is a stub

Xcode links Debug builds so that `App.app/App` is a ~58 KB launcher and the code
lives in **`App.app/App.debug.dylib`** beside it. `strings` on the executable returns
nothing for every string you look for, so every check "passes" and the Debug column
of your table is silently meaningless.

```bash
ls -la App.app/App              # ~58 KB? it is a stub
strings -a App.app/App.debug.dylib | grep -c recordingModeEnabled
```

`strings` also needs `-a` here.

### Do not grep the source for `error:`

When a build fails, capture the log and check the exit code:

```bash
xcodebuild ... > /tmp/build.log 2>&1; echo "exit=$?"
grep -E '^/.*\.swift:[0-9]+:[0-9]+: error:' /tmp/build.log
```

A bare `grep error:` matches source lines that merely contain the word — `@Binding
var error: String?` — and reports failure on a clean build. Anchoring to the
`file:line:col: error:` shape is what makes it a compiler error rather than a
coincidence.

---

## 2. Layout does not shift

On Dynamic Island and notch devices the top safe-area inset comes from the physical
cutout, not the status bar, so hiding the bar should not move anything. Should. If it
does, every composite is misaligned, so measure it.

Capture the same screen twice. A launch argument sets `UserDefaults` for that launch,
so no rebuild is needed between shots:

```bash
xcrun simctl launch "iPhone 17 Pro" com.example.app -recordingModeEnabled NO
xcrun simctl io "iPhone 17 Pro" screenshot off.png
xcrun simctl terminate "iPhone 17 Pro" com.example.app
xcrun simctl launch "iPhone 17 Pro" com.example.app -recordingModeEnabled YES
xcrun simctl io "iPhone 17 Pro" screenshot on.png
```

Then cross-correlate the content region, below the status bar and above the home
indicator, over a range of vertical shifts. The answer you want is a sharp minimum at
zero:

```python
from PIL import Image
a = Image.open('off.png').convert('L'); b = Image.open('on.png').convert('L')
W, H = a.size; pa, pb = a.load(), b.load()
XS = range(0, W, 6)

def err(shift):
    t = n = 0
    for y in range(300, H - 200, 3):
        for x in XS:
            t += abs(pa[x, y] - pb[x, y + shift]); n += 1
    return t / n

for s in range(-8, 9):
    print(f"{s:+3d}px -> {err(s):7.3f}")
```

A real result. The minimum is at 0 and rises steeply either side, which is what
"nothing moved" looks like:

```
 -4px ->   8.186
 -1px ->   3.039
 +0px ->   0.610
 +1px ->   3.040
 +4px ->   8.310
```

**A flat curve means the two screenshots are the same image** — the flag did nothing,
or you captured the same variant twice. Check that the status bar region actually
differs before trusting the content region:

```python
first = next(y for y in range(H)
             if any(abs(pa[x, y] - pb[x, y]) > 24 for x in range(0, W, 4)))
print("first differing row:", first)   # expect a small number
```

If the first differing row is far down the screen, the status bar never hid. That is
exactly how the early-return bug was caught: identical across the top 1840 rows.

---

## 3. It works on a device

**The simulator cannot test the recording indicator.** `simctl io recordVideo` writes
a file without ever drawing an indicator, so a simulator capture shows a clean island
whether or not the flag works, and proves nothing either way.

On a device: start a screen recording from Control Center, open the app, toggle
recording mode, and look at the island.

Verified on iPhone 17 Pro, iOS 26, while recording:

| | Flag off | Flag on |
|---|---|---|
| Time | 20:46 | gone |
| Signal / carrier / battery | shown | gone |
| Red recording dot on the island | shown, with red island outline | **gone** |

The indicator being suppressed was not expected. The indicator is drawn by
SpringBoard, not the app, so the reasonable assumption is that an app-level modifier
cannot touch it. The assumption is wrong, which is the single most useful thing in
this skill and worth re-checking on any new iOS major version rather than trusting
this table forever.
