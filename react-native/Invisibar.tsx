/**
 * Invisibar — https://github.com/gokhunguneyhan/invisibar
 *
 * Hide the iOS status bar for your product screenshots and recordings, which also
 * removes the red screen-recording indicator from the Dynamic Island.
 *
 * Works in bare React Native and in Expo, unchanged. No native modules, no
 * dependencies beyond react-native itself.
 *
 *   // 1. wrap your app root
 *   export default () => <Invisibar><App /></Invisibar>;
 *
 *   // 2. anywhere you can spare a footnote, e.g. under a settings list
 *   <InvisibarLink />
 *
 * Tap the footnote, pick Hide or Replace, then scroll the link out of frame and
 * record.
 *
 * RELEASE SAFETY. Everything is behind `__DEV__`, which Metro's minifier treats as a
 * constant `false` in production and strips along with the dead branch. In a release
 * bundle `<InvisibarLink />` renders null and `<Invisibar>` renders its children
 * untouched. Verify on your own release bundle, and use a control string or a clean
 * zero proves nothing:
 *
 *   npx react-native bundle --dev false --platform ios \
 *     --entry-file index.js --bundle-output /tmp/main.jsbundle
 *   grep -c invisibarMode /tmp/main.jsbundle        # want 0
 *   grep -c someStringYouKnowShips /tmp/main.jsbundle   # control, must be non-zero
 *
 * iOS only by nature: Android has no Dynamic Island and draws its own recording
 * indicator, which this cannot touch.
 *
 * MIT licensed.
 */

import React, {useState, useSyncExternalStore} from 'react';
import {
  Linking,
  Modal,
  Platform,
  Pressable,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  useWindowDimensions,
  View,
} from 'react-native';

type Mode = 'off' | 'hide' | 'replace';

/* ------------------------------------------------------------------ store --
 * A module-level store rather than Context, so <InvisibarLink /> works wherever
 * it is mounted without having to sit inside a provider.
 *
 * Deliberately NOT persisted. AsyncStorage would be a dependency, and a capture
 * mode that resets on reload is the safer default: you cannot get stuck with a
 * hidden status bar and no way back.
 */
let currentMode: Mode = 'off';
const listeners = new Set<() => void>();

const subscribe = (fn: () => void) => {
  listeners.add(fn);
  return () => listeners.delete(fn);
};
const getMode = () => currentMode;
const setMode = (m: Mode) => {
  currentMode = m;
  listeners.forEach(fn => fn());
};
const useMode = (): Mode => useSyncExternalStore(subscribe, getMode, getMode);

/* -------------------------------------------------------------- public API */

/** Wrap your app root. Renders children untouched in production. */
export function Invisibar({children}: {children: React.ReactNode}) {
  if (!__DEV__ || Platform.OS !== 'ios') return <>{children}</>;
  return <InvisibarRoot>{children}</InvisibarRoot>;
}

/** A dim footnote reading "Invisibar". Renders null in production. */
export function InvisibarLink(props: {style?: any}) {
  if (!__DEV__ || Platform.OS !== 'ios') return null;
  return <InvisibarLinkBody {...props} />;
}

/* ------------------------------------------------------------------- root */

function InvisibarRoot({children}: {children: React.ReactNode}) {
  const mode = useMode();
  return (
    <>
      {children}
      <StatusBar hidden={mode !== 'off'} />
      {mode === 'replace' && <InvisibarStatusBar />}
    </>
  );
}

/* --------------------------------------------------------------- footnote */

function InvisibarLinkBody({style}: {style?: any}) {
  const mode = useMode();
  const [open, setOpen] = useState(false);
  const scheme = useColorScheme();
  const dim = scheme === 'dark' ? '#8E8E93' : '#6C6C70';

  return (
    <>
      <Pressable onPress={() => setOpen(true)} style={style}>
        <View style={s.linkRow}>
          <Text style={[s.link, {color: dim}]}>Invisibar</Text>
          {mode !== 'off' && (
            <View style={[s.dot, {backgroundColor: dim}]} />
          )}
        </View>
      </Pressable>
      <InvisibarSheet open={open} onClose={() => setOpen(false)} />
    </>
  );
}

/* ------------------------------------------------------------------ sheet */

function InvisibarSheet({open, onClose}: {open: boolean; onClose: () => void}) {
  const mode = useMode();
  const scheme = useColorScheme();
  const dark = scheme === 'dark';
  const bg = dark ? '#1C1C1E' : '#FFFFFF';
  const ink = dark ? '#FFFFFF' : '#000000';
  const dim = dark ? '#8E8E93' : '#6C6C70';
  const line = dark ? '#38383A' : '#D1D1D6';

  const row = (m: Mode, title: string, subtitle: string) => (
    <Pressable
      // Deliberately does not close: you often want to try one, look, and try
      // the other.
      onPress={() => setMode(m)}>
      <View style={s.row}>
        <View style={s.rowText}>
          <Text style={[s.rowTitle, {color: ink}]}>{title}</Text>
          <Text style={[s.rowSubtitle, {color: dim}]}>{subtitle}</Text>
        </View>
        <View
          style={[
            s.radio,
            {borderColor: mode === m ? '#0A84FF' : dim},
            mode === m && {backgroundColor: '#0A84FF'},
          ]}>
          {mode === m && <Text style={s.tick}>✓</Text>}
        </View>
      </View>
    </Pressable>
  );

  return (
    <Modal
      visible={open}
      transparent
      animationType="slide"
      onRequestClose={onClose}>
      <Pressable style={s.backdrop} onPress={onClose} />
      <View style={[s.sheet, {backgroundColor: bg}]}>
        <View style={[s.grabber, {backgroundColor: line}]} />

        <Text style={[s.title, {color: ink}]}>Invisibar</Text>
        <Text style={[s.subtitle, {color: dim}]}>
          {'For screenshots and screen recordings.\n'}
          Also removes the red recording indicator.
        </Text>

        <View style={s.rows}>
          {row('off', 'Off', 'Leave the real status bar alone.')}
          <View style={[s.divider, {backgroundColor: line}]} />
          {row('hide', 'Hide status bar',
               'No clock, battery, signal or recording indicator.')}
          <View style={[s.divider, {backgroundColor: line}]} />
          {row('replace', 'Replace status bar',
               'Draws a clean 9:41 and a full battery instead.')}
        </View>

        <Text style={[s.credit, {color: dim}]}>Built by Gokhun Guneyhan</Text>
        <View style={s.links}>
          <Pressable
            hitSlop={8}
            onPress={() => Linking.openURL('https://x.com/gokhunguneyhan')}>
            <Text style={[s.linkOut, {color: dim}]}>X</Text>
          </Pressable>
          <Text style={[s.linkOut, {color: line}]}>/</Text>
          <Pressable
            hitSlop={8}
            onPress={() =>
              Linking.openURL('https://github.com/gokhunguneyhan/invisibar')
            }>
            <Text style={[s.linkOut, {color: dim}]}>GitHub</Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

/* -------------------------------------------------------- the drawn bar --
 * Geometry measured from 1206x2622 captures of a 402pt-wide 3x device on iOS 26,
 * expressed as fractions of the width so it travels to other sizes. Check it
 * against a screenshot of your own device before shooting a lot of footage.
 *
 * Do NOT calibrate against a capture taken while screen recording: the Dynamic
 * Island is expanded then and pushes the time left, 61.5pt versus 74.2pt idle.
 * The vertical band is the same in both, which is why it is the number to trust.
 *
 * No Wi-Fi glyph: arcs need SVG, and this file stays dependency-free.
 */
function InvisibarStatusBar({
  time = '9:41',
  batteryLevel = 1,
}: {
  time?: string;
  batteryLevel?: number;
}) {
  const {width} = useWindowDimensions();
  const scheme = useColorScheme();
  const tint = scheme === 'dark' ? '#FFFFFF' : '#000000';

  const timeCentre = width * (74.2 / 402);
  const trailing = width * (31.3 / 402);
  const bandTop = 26.7;

  return (
    <View style={s.bar} pointerEvents="none">
      <Text
        style={[
          s.time,
          {
            color: tint,
            top: bandTop - 1,
            // A fixed-width box starting at 0 centres the text on its midpoint,
            // so this holds however wide the string renders.
            width: timeCentre * 2,
          },
        ]}>
        {time}
      </Text>

      <View style={[s.cluster, {top: bandTop, right: trailing}]}>
        {[4, 6.3, 8.7, 11.3].map((h, i) => (
          <View
            key={i}
            style={{
              width: 3,
              height: h,
              borderRadius: 0.8,
              marginRight: 1.7,
              backgroundColor: tint,
            }}
          />
        ))}
        <View style={{width: 4.2}} />
        <View style={s.battery}>
          <View style={[s.batteryBody, {borderColor: tint, opacity: 0.38}]} />
          <View
            style={[
              s.batteryFill,
              {
                backgroundColor: tint,
                width: 21 * Math.min(Math.max(batteryLevel, 0), 1),
              },
            ]}
          />
          <View style={[s.nub, {backgroundColor: tint, opacity: 0.38}]} />
        </View>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  linkRow: {flexDirection: 'row', alignItems: 'center'},
  link: {fontSize: 13},
  dot: {width: 5, height: 5, borderRadius: 2.5, marginLeft: 5},

  backdrop: {...StyleSheet.absoluteFillObject, backgroundColor: '#00000055'},
  sheet: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    paddingHorizontal: 24,
    paddingBottom: 28,
    borderTopLeftRadius: 14,
    borderTopRightRadius: 14,
  },
  grabber: {
    width: 36,
    height: 5,
    borderRadius: 2.5,
    alignSelf: 'center',
    marginTop: 8,
  },
  title: {fontSize: 20, fontWeight: '600', textAlign: 'center', marginTop: 16},
  subtitle: {fontSize: 15, textAlign: 'center', marginTop: 6, lineHeight: 20},
  rows: {marginTop: 20},
  divider: {height: StyleSheet.hairlineWidth, marginLeft: 2},
  row: {flexDirection: 'row', alignItems: 'center', paddingVertical: 12},
  rowText: {flex: 1, paddingRight: 8},
  rowTitle: {fontSize: 17},
  rowSubtitle: {fontSize: 12, marginTop: 2},
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tick: {color: '#FFFFFF', fontSize: 13, fontWeight: '700'},
  credit: {fontSize: 13, textAlign: 'center', marginTop: 20},
  links: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 4,
  },
  // Same size as the credit above. The padding, not the type size, carries
  // the tap target.
  linkOut: {fontSize: 13, paddingHorizontal: 10, paddingVertical: 10},

  bar: {position: 'absolute', top: 0, left: 0, right: 0, height: 54},
  time: {position: 'absolute', fontSize: 17, fontWeight: '600', textAlign: 'center'},
  cluster: {position: 'absolute', flexDirection: 'row', alignItems: 'flex-end', height: 12},
  battery: {flexDirection: 'row', alignItems: 'center', height: 12},
  batteryBody: {
    width: 25,
    height: 12,
    borderWidth: 1,
    borderRadius: 3.8,
    position: 'absolute',
  },
  batteryFill: {height: 8, borderRadius: 1.8, marginLeft: 2},
  nub: {width: 1.6, height: 4.2, borderRadius: 0.8, marginLeft: 25 - 21 - 2 + 1},
});
