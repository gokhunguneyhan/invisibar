//  Invisibar.swift
//  https://github.com/gokhunguneyhan/invisibar
//
//  Hide the iOS status bar for your product screenshots and recordings — which also
//  removes the red screen-recording indicator from the Dynamic Island.
//
//  Drop this file into your app. Two call sites:
//
//      @main struct MyApp: App {
//          var body: some Scene {
//              WindowGroup { RootView().invisibar() }    // 1. at the root
//          }
//      }
//
//      // 2. anywhere you can spare a footnote, e.g. under a settings list
//      InvisibarLink()
//
//  Tap the footnote, pick Hide or Replace, then scroll the link out of frame and
//  record. Tap it again to turn it off.
//
//  RELEASE SAFETY. Everything below is a no-op in Release: `InvisibarLink` renders
//  `EmptyView`, `.invisibar()` returns the view untouched, and no UserDefaults key is
//  ever read or written. Both call sites still compile, so you can leave them in.
//
//  Measured on a real Release build, against a control string:
//
//      invisibarMode          Debug 1   Release 0
//      "Hide status bar"      Debug 1   Release 0
//      "9:41"                 Debug 2   Release 0
//      InvisibarLink          Debug 5   Release 2   <- type metadata only
//      didRepairPermissions   Debug 1   Release 2   <- control, must be non-zero
//
//  The type name survives because the API has to exist for your call sites to
//  compile. It carries no behaviour and touches no storage. Verify your own build
//  the same way; see references/verify.md, and use a control string or a clean zero
//  proves nothing at all.
//
//  MIT licensed.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Public API

public extension View {
    /// Apply at the OUTERMOST view your app shows. If your root `body` returns early
    /// for any branch — a launch argument, a loading state, a separate onboarding
    /// root — apply this above the branch, or those screens keep their status bar.
    func invisibar() -> some View {
        #if DEBUG
        modifier(InvisibarModifier())
        #else
        self
        #endif
    }
}

/// A dim footnote button reading "Invisibar". Sized to disappear into the bottom of a
/// settings screen, so a small scroll leaves it out of shot.
public struct InvisibarLink: View {
    public init() {}

    public var body: some View {
        #if DEBUG
        InvisibarLinkBody()
        #else
        EmptyView()
        #endif
    }
}

#if DEBUG

// MARK: - Mode

enum InvisibarMode: String {
    case off, hide, replace

    static let storageKey = "invisibarMode"
}

// MARK: - The footnote

private struct InvisibarLinkBody: View {
    @AppStorage(InvisibarMode.storageKey) private var raw = InvisibarMode.off.rawValue
    @State private var sheet = false

    private var mode: InvisibarMode { InvisibarMode(rawValue: raw) ?? .off }

    var body: some View {
        Button { sheet = true } label: {
            HStack(spacing: 5) {
                Text("Invisibar")
                if mode != .off {
                    // Only marking when it is ON, so the resting state stays quiet.
                    Circle().frame(width: 5, height: 5)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $sheet) { InvisibarSheet(raw: $raw) }
    }
}

// MARK: - The sheet

private struct InvisibarSheet: View {
    @Binding var raw: String

    private var mode: InvisibarMode { InvisibarMode(rawValue: raw) ?? .off }

    var body: some View {
        VStack(spacing: 0) {
            InvisibarMascot()
                .padding(.top, 44)

            Text("Invisibar")
                .font(.title3.weight(.semibold))
                .padding(.top, 28)

            // The break is deliberate: one line for what it is, one for the part
            // people do not expect.
            Text("For screenshots and screen recordings.\nAlso removes the red "
                 + "recording indicator.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            VStack(spacing: 0) {
                // Off leads, so turning it back off is the first thing you see.
                row(.off, "Off", "Leave the real status bar alone.")
                Divider().padding(.leading, 2)
                row(.hide, "Hide status bar",
                    "No clock, battery, signal or recording indicator.")
                Divider().padding(.leading, 2)
                row(.replace, "Replace status bar",
                    "Draws a clean 9:41 and a full battery instead.")
            }
            .padding(.top, 20)

            Spacer(minLength: 16)

            Text("Built by Gokhun Guneyhan")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Link("X", destination: URL(string: "https://x.com/gokhunguneyhan")!)
                    .padding(.horizontal, 10).padding(.vertical, 10)
                Text("/").foregroundStyle(.tertiary)
                Link("GitHub", destination:
                        URL(string: "https://github.com/gokhunguneyhan/invisibar")!)
                    .padding(.horizontal, 10).padding(.vertical, 10)
            }
            // Same size as the credit above. The padding, not the type size,
            // carries the tap target.
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(485)])
        .presentationDragIndicator(.visible)
    }

    private func row(_ m: InvisibarMode, _ title: String, _ subtitle: String) -> some View {
        Button {
            // Deliberately does NOT dismiss. You often want to try one, look, and
            // try the other; a sheet that closes on every tap makes that tedious.
            raw = m.rawValue
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: mode == m ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(mode == m ? Color.accentColor : Color.secondary)
                    .font(.system(size: 20))
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - The modifier

private struct InvisibarModifier: ViewModifier {
    @AppStorage(InvisibarMode.storageKey) private var raw = InvisibarMode.off.rawValue

    private var mode: InvisibarMode { InvisibarMode(rawValue: raw) ?? .off }

    func body(content: Content) -> some View {
        content
            .statusBarHidden(mode != .off)
            .overlay(alignment: .top) {
                if mode == .replace {
                    InvisibarStatusBar().allowsHitTesting(false)
                }
            }
    }
}

// MARK: - The mascot
//
// Embedded as base64 rather than shipped as an asset-catalog image, so this stays a
// single drop-in file. A PNG would mean every adopter also has to add three files to
// their own catalog, which is most of the reason not to bother with a small tool.
//
// The source is 480x180, drawn into a 112x42pt slot (the same 8:3 ratio), so it is
// oversampled rather than stretched. Transparent background, so it sits on a light or a
// dark sheet without a plate behind it.
private let invisibarMascotPNG = """
        iVBORw0KGgoAAAANSUhEUgAAAeAAAAC0CAMAAAB7Yg/yAAACo1BMVEUAAAAmLzNOXWdTancTFR6FnaxMaHZ1gpYuPUu9
        xNA3lZnEyNRAUGOIk6hNfYpFtbeJk6preI6wutE3R1tSy8uJk6vc4u8nipKosciMmbFVYHlf3989s7QwRVu5wdh9h5/b
        3+4/xciUn7mpscoigo2Djadp8PDl6vZJVnCyutWlrshK2NlZZoQrrLLCyuOTobzu8vx9i6YuNk0ggYy1vtXH0OVj7Os6
        v8Wnscmcpr/u9P2+xNvM0+mwuNKBp8OLlK+UnLiEjaho9fWjq8W2vtVFxcb+///4+fz09fnw8vft7vTq6/Hn6vLm5+3i
        5Ozf4end3+jc3eXY3OjZ2+TX2ePU2ebV1+HS1eCp6ObQ093O0dzMz9vKzdnIy9jHytXEyNWO397CxdK/w9C9wc6A2tm6
        vsy4vMt419a1usm0uMdV4uGyt8Zy1NOxtcWvs8Rt0tGtssOsscFn0NCosMirr8Cprr+orb5izc2nq72lq71dzMylqbuj
        qbtG0tNYysqip7mgprhUyMikpK2do7edo7VPxcWbobWZn7OXnbFKwcGVm6+Vmq2Tmq+Tma1Dvb2RmK2Rl6uPlquPlamN
        lKk+uLiNk6czvL6LkaeLkaWJj6WJj6OHjaM6sbOFi6GEi6CDiZ+DiZwxrq9xjqaBh55/hZw0qKt9g5l6gJYqpKd3fpQ0
        nKRmgph0e5EmnaByeY9vdoxefJEklppsc4lpcIYfj5RmbYNjaoFhaH4ye40chotdZXxWZIFbYngafINYX3VOXXtTW3JQ
        WG4raHwYcnpMVGpFVXNIT2YWZnBFTWNBSV8+RVwSWGM8Q1gpSmM4PlQyPVs0O1ExN0wkNVEsMkcmLUIkKj0dJjwUHjkZ
        HC0OFzMKEy0IESkIDycGDCIDBRkBAxEAAAYPZ6SNAAAAsXRSTlMAAw4bJSsvPz9ER1FSVltlanJ0d3+BjY6Zm5qenq2u
        rrCwtLe9v8LIys7P0dDT1dXW29rc4OLi4+fn6ejv7+/v8fL09f38////////////////////////////////////////
        /////////v///////////v////////////7////////////////////////////////+///////////////+////////
        //7+//////4MdNqkAABcRklEQVR42uzXz0sUcRjH8c/z/c53nN1AYxvT0hKhtkILO6x4CI1FMwiCOoQQ2GIbC8O44uCP
        lHapgwcvewjZk6cFT/sndfXiJbCWdnMdpxElgojWdRbZ4XkdhmEYmMN7eOYZMMYYY+w86ORIYKFEoC7T7AS4cEiJZG5r
        Kxc/a2B+I9pFPAvf3ud9nJEAawNy0oBvoB8cOJyuwGcogEd0OA2t1OH7uAsWSjK3vbOzPUqt+wkTPMwvEEH2Dw6aBELw
        iCDNeDI52hflkX5RqHVfVALMpOXYtmMlRxUXbjMC/xd/NSa+VSpf3ZFn75THhcOF0Jf75GRSMzOplJ0vWBIsXHSrkHfS
        qRm/cGZ9anuIh3Sg6K+z1o5oAmSXaXbJ3w+8PVwFJI4p93HtetQDCwx5ojcxcmckcTPiEbU+MHkqPvF2dvb1RPz0aytf
        HmlSKc0wDA3AwYsesAD7qifTD8fGE/enn1/10BSCkALU4L2mlV+10+mMk7OiIADRYnFzY92x0/7FhdWNQnGKR3SAxNPs
        8spSdn4++/5NrMm+sfHSeDeosYXKOl6ofJnVqZPCncViYTO/vmBnbNvJ+4FzvGYFqHdueW1tZXlxaXHpwyNCM7pL5XK5
        dLmREe1F5wZ+HLio1eDWErdS0iMAug6pGbohpYIG/RoHDtCNGFxXaIboEO6AjiaIe5FqtRp50EhgDPfUcMp1v3+5C+Dw
        koLSIJWEBKCrmAYWFILmSV1C6prCno5mRf65hGv4QzR1ZLh11AwA9bo7Wdndx2HHT+MXO+YSY1lRxvH/V3XqnnP73Ds9
        3T0wDyBDdAZGfERBiYDALIQENyZsVBY+FkSCyFadhRAXxgUKccMOYiQYEmNC1ExINAiBQJBAjJlo5E0EmZ6H/bp9H+dU
        fXad+qxU+qaZM+1M3MzX59bz3Dp161ffv77TkwywEM81BhfsXBmPc9Ia5Iu0d4JtmFv2eIevcQsP7peFKXudIs8ybWw9
        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
"""

private struct InvisibarMascot: View {
    /// Decoded once. Failing to decode renders nothing rather than a broken-image box:
    /// the sheet still works without its picture.
    private static let image: Image? = {
        guard let data = Data(base64Encoded: invisibarMascotPNG, options: .ignoreUnknownCharacters),
              let ui = UIImage(data: data, scale: 3) else { return nil }
        return Image(uiImage: ui)
    }()

    var body: some View {
        if let image = Self.image {
            image.resizable().scaledToFit().frame(width: 112, height: 42)
        }
    }
}

// MARK: - The drawn status bar

/// A stand-in for the real status bar, for `replace` mode.
///
/// Geometry measured from 1206x2622 captures of a 402pt-wide 3x device on iOS 26, and
/// expressed as fractions of the width so it travels to other sizes. Not pixel-exact
/// everywhere: check it against a screenshot of your own device before shooting a lot
/// of footage.
///
/// Do not calibrate against a capture taken WHILE screen recording. The Dynamic Island
/// is expanded in that state and pushes the time left — 61.5pt versus 74.2pt idle. The
/// vertical band is the same in both, which is why it is the number to trust.
struct InvisibarStatusBar: View {
    var time: String = "9:41"
    var batteryLevel: Double = 1.0
    var showsCellular: Bool = true
    var showsWiFi: Bool = true

    @Environment(\.colorScheme) private var scheme

    // Fractions of the screen width, from the reference capture.
    private let timeCentreFraction = 74.2 / 402.0
    private let trailingFraction = 31.3 / 402.0
    private let bandTop: CGFloat = 26.7      // identical in every capture taken

    private var tint: Color { scheme == .dark ? .white : .black }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Text(time)
                    .font(.system(size: 17, weight: .semibold))
                    // A fixed-width frame centred on 0 puts the midpoint at half the
                    // width, so this places the time regardless of how wide it renders.
                    .frame(width: w * timeCentreFraction * 2)
                    .position(x: w * timeCentreFraction, y: bandTop + 5.8)

                HStack(spacing: 4.2) {
                    if showsCellular {
                        Image(systemName: "cellularbars")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    if showsWiFi {
                        Image(systemName: "wifi")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    BatteryGlyph(level: batteryLevel, tint: tint)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, w * trailingFraction)
                .position(x: w / 2, y: bandTop + 5.8)
            }
            .foregroundStyle(tint)
        }
        .frame(height: 54)
        .ignoresSafeArea(edges: .top)
    }
}

/// 25 x 12pt body with a nub, matching Apple's proportions. The outline and nub are
/// translucent; the level fill is solid, as iOS draws it.
private struct BatteryGlyph: View {
    var level: Double
    var tint: Color

    var body: some View {
        HStack(spacing: 1.0) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.8, style: .continuous)
                    .stroke(tint.opacity(0.38), lineWidth: 1)
                    .frame(width: 25, height: 12)
                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                    .fill(tint)
                    .frame(width: max(0, 21 * min(max(level, 0), 1)), height: 8)
                    .padding(.leading, 2)
            }
            Capsule().fill(tint.opacity(0.38)).frame(width: 1.6, height: 4.2)
        }
    }
}

#endif
