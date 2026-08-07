/// Invisibar — https://github.com/gokhunguneyhan/invisibar
///
/// Hide the iOS status bar for your product screenshots and recordings, which also
/// removes the red screen-recording indicator from the Dynamic Island.
///
/// No plugins, no dependencies beyond Flutter itself.
///
///   // 1. wrap your app root
///   runApp(const Invisibar(child: MyApp()));
///
///   // 2. anywhere you can spare a footnote, e.g. under a settings list
///   const InvisibarLink()
///
/// Tap the footnote, pick Hide or Replace, then scroll the link out of frame and
/// record.
///
/// RELEASE SAFETY. Everything is behind `kDebugMode`, which is a compile-time
/// constant in release builds, so the tree-shaker removes the dead branch.
/// `InvisibarLink` builds a `SizedBox.shrink()` and `Invisibar` returns its child
/// untouched. Verify on your own release build, and use a control string or a clean
/// zero proves nothing:
///
///   flutter build ios --release
///   strings -a build/ios/.../Runner.app/Frameworks/App.framework/App \
///     | grep -c Invisibar
///
/// iOS only by nature: Android has no Dynamic Island and draws its own recording
/// indicator, which this cannot touch.
///
/// MIT licensed.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum InvisibarMode { off, hide, replace }

/// Deliberately not persisted. A capture mode that resets on restart is the safer
/// default: you cannot get stuck with a hidden status bar and no way back.
final ValueNotifier<InvisibarMode> _mode =
    ValueNotifier<InvisibarMode>(InvisibarMode.off);

/// Wrap your app root. Returns the child untouched in release.
class Invisibar extends StatelessWidget {
  const Invisibar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return ValueListenableBuilder<InvisibarMode>(
      valueListenable: _mode,
      builder: (context, mode, _) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: mode == InvisibarMode.off
              ? SystemUiOverlay.values
              : const <SystemUiOverlay>[],
        );
        return Stack(
          children: [
            child,
            if (mode == InvisibarMode.replace)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _InvisibarStatusBar()),
              ),
          ],
        );
      },
    );
  }
}

/// A dim footnote reading "Invisibar". Builds nothing in release.
class InvisibarLink extends StatelessWidget {
  const InvisibarLink({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ValueListenableBuilder<InvisibarMode>(
      valueListenable: _mode,
      builder: (context, mode, _) {
        final dim = Theme.of(context).textTheme.bodySmall?.color;
        return GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => const _InvisibarSheet(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invisibar', style: TextStyle(fontSize: 13, color: dim)),
              if (mode != InvisibarMode.off) ...[
                const SizedBox(width: 5),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: dim, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InvisibarSheet extends StatelessWidget {
  const _InvisibarSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.textTheme.bodySmall?.color;

    Widget row(InvisibarMode m, String title, String subtitle) {
      return ValueListenableBuilder<InvisibarMode>(
        valueListenable: _mode,
        builder: (context, mode, _) => InkWell(
          // Deliberately does not pop: you often want to try one, look, and try
          // the other.
          onTap: () => _mode.value = m,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12, color: dim)),
                    ],
                  ),
                ),
                Icon(
                  mode == m ? Icons.check_circle : Icons.circle_outlined,
                  color: mode == m ? theme.colorScheme.primary : dim,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invisibar',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'For screenshots and screen recordings.\n'
            'Also removes the red recording indicator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: dim),
          ),
          const SizedBox(height: 20),
          row(InvisibarMode.off, 'Off', 'Leave the real status bar alone.'),
          const Divider(height: 1),
          row(InvisibarMode.hide, 'Hide status bar',
              'No clock, battery, signal or recording indicator.'),
          const Divider(height: 1),
          row(InvisibarMode.replace, 'Replace status bar',
              'Draws a clean 9:41 and a full battery instead.'),
          const SizedBox(height: 20),
          Text('Built by Gokhun Guneyhan',
              style: TextStyle(fontSize: 13, color: dim)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LinkText('x', 'https://x.com/gokhunguneyhan', dim),
              Text('/', style: TextStyle(fontSize: 16, color: dim)),
              _LinkText('github',
                  'https://github.com/gokhunguneyhan/invisibar', dim),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.label, this.url, this.color);

  final String label;
  final String url;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // No url_launcher dependency: copying the URL is enough for a dev tool, and
    // keeping this file plugin-free is worth more than opening a browser.
    return TextButton(
      onPressed: () => Clipboard.setData(ClipboardData(text: url)),
      child: Text(label, style: TextStyle(fontSize: 16, color: color)),
    );
  }
}

/// Geometry measured from 1206x2622 captures of a 402pt-wide 3x device on iOS 26,
/// expressed as fractions of the width so it travels to other sizes. Check it
/// against a screenshot of your own device before shooting a lot of footage.
///
/// Do NOT calibrate against a capture taken while screen recording: the Dynamic
/// Island is expanded then and pushes the time left, 61.5pt versus 74.2pt idle. The
/// vertical band is the same in both, which is why it is the number to trust.
///
/// No Wi-Fi glyph: arcs need a custom painter, and this stays deliberately small.
class _InvisibarStatusBar extends StatelessWidget {
  const _InvisibarStatusBar({this.time = '9:41', this.batteryLevel = 1.0});

  final String time;
  final double batteryLevel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Colors.white : Colors.black;

    final timeCentre = width * (74.2 / 402);
    final trailing = width * (31.3 / 402);
    const bandTop = 26.7;

    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          Positioned(
            top: bandTop - 1,
            left: 0,
            // A fixed-width box starting at 0 centres the text on its midpoint,
            // so this holds however wide the string renders.
            width: timeCentre * 2,
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: tint),
            ),
          ),
          Positioned(
            top: bandTop,
            right: trailing,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final h in const [4.0, 6.3, 8.7, 11.3])
                  Container(
                    width: 3,
                    height: h,
                    margin: const EdgeInsets.only(right: 1.7),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(0.8),
                    ),
                  ),
                const SizedBox(width: 4.2),
                _Battery(level: batteryLevel, tint: tint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery({required this.level, required this.tint});

  final double level;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 25,
          height: 12,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: tint.withOpacity(0.38), width: 1),
                  borderRadius: BorderRadius.circular(3.8),
                ),
              ),
              Positioned(
                left: 2,
                top: 2,
                child: Container(
                  width: 21 * level.clamp(0.0, 1.0),
                  height: 8,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(1.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 1),
        Container(
          width: 1.6,
          height: 4.2,
          decoration: BoxDecoration(
            color: tint.withOpacity(0.38),
            borderRadius: BorderRadius.circular(0.8),
          ),
        ),
      ],
    );
  }
}
