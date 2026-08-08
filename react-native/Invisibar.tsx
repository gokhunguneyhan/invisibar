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
  Image,
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

        <InvisibarMascot />

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

/* ----------------------------------------------------------------- mascot --
 * Embedded as base64 rather than shipped as an asset, so this stays a single
 * drop-in file. Behind `__DEV__` like everything else here, so the string is
 * dead code in a release bundle and goes out with the rest of it.
 *
 * The source is 480x180, drawn into a 112x42pt slot (the same 8:3 ratio), so it
 * is oversampled rather than stretched. Transparent background, so it sits on a
 * light or a dark sheet without a plate behind it.
 */
const invisibarMascotPNG = `
  iVBORw0KGgoAAAANSUhEUgAAAeAAAAC0CAMAAAB7Yg/yAAACo1BMVEUAAAAmLzNOXWdTancTFR6FnaxMaHZ1gpYuPUu9xN
  A3lZnEyNRAUGOIk6hNfYpFtbeJk6preI6wutE3R1tSy8uJk6vc4u8nipKosciMmbFVYHlf3989s7QwRVu5wdh9h5/b3+4/
  xciUn7mpscoigo2Djadp8PDl6vZJVnCyutWlrshK2NlZZoQrrLLCyuOTobzu8vx9i6YuNk0ggYy1vtXH0OVj7Os6v8Wnsc
  mcpr/u9P2+xNvM0+mwuNKBp8OLlK+UnLiEjaho9fWjq8W2vtVFxcb+///4+fz09fnw8vft7vTq6/Hn6vLm5+3i5Ozf4end
  3+jc3eXY3OjZ2+TX2ePU2ebV1+HS1eCp6ObQ093O0dzMz9vKzdnIy9jHytXEyNWO397CxdK/w9C9wc6A2tm6vsy4vMt419
  a1usm0uMdV4uGyt8Zy1NOxtcWvs8Rt0tGtssOsscFn0NCosMirr8Cprr+orb5izc2nq72lq71dzMylqbujqbtG0tNYysqi
  p7mgprhUyMikpK2do7edo7VPxcWbobWZn7OXnbFKwcGVm6+Vmq2Tmq+Tma1Dvb2RmK2Rl6uPlquPlamNlKk+uLiNk6czvL
  6LkaeLkaWJj6WJj6OHjaM6sbOFi6GEi6CDiZ+DiZwxrq9xjqaBh55/hZw0qKt9g5l6gJYqpKd3fpQ0nKRmgph0e5EmnaBy
  eY9vdoxefJEklppsc4lpcIYfj5RmbYNjaoFhaH4ye40chotdZXxWZIFbYngafINYX3VOXXtTW3JQWG4raHwYcnpMVGpFVX
  NIT2YWZnBFTWNBSV8+RVwSWGM8Q1gpSmM4PlQyPVs0O1ExN0wkNVEsMkcmLUIkKj0dJjwUHjkZHC0OFzMKEy0IESkIDycG
  DCIDBRkBAxEAAAYPZ6SNAAAAsXRSTlMAAw4bJSsvPz9ER1FSVltlanJ0d3+BjY6Zm5qenq2urrCwtLe9v8LIys7P0dDT1d
  XW29rc4OLi4+fn6ejv7+/v8fL09f38/////////////////////////////////////////////////v///////////v//
  //////////7////////////////////////////////+///////////////+//////////7+//////4MdNqkAABcRklEQV
  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
  EBWqYKXV45ieAAAAAElFTkSuQmCC
`;

// Wrapped for readability above, so the newlines come back out here.
const invisibarMascotURI =
  'data:image/png;base64,' + invisibarMascotPNG.replace(/\s/g, '');

function InvisibarMascot() {
  return (
    <Image
      source={{uri: invisibarMascotURI}}
      style={s.mascot}
      resizeMode="contain"
    />
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
  // 44pt from the top of the sheet, less the 13pt the grabber already takes.
  mascot: {width: 112, height: 42, alignSelf: 'center', marginTop: 31},
  title: {fontSize: 20, fontWeight: '600', textAlign: 'center', marginTop: 28},
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
