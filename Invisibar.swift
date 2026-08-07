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
    @Environment(\.dismiss) private var dismiss

    private var mode: InvisibarMode { InvisibarMode(rawValue: raw) ?? .off }

    /// Tapping the active row turns it off, so two rows cover three states and there
    /// is no "Off" row to explain.
    private func pick(_ m: InvisibarMode) {
        raw = (mode == m ? .off : m).rawValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Invisibar")
                .font(.title3.weight(.semibold))
                .padding(.top, 24)

            Text("For screenshots and screen recordings. Also removes the red "
                 + "recording indicator.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            VStack(spacing: 0) {
                row(.hide, "Hide status bar",
                    "No clock, battery, signal or recording indicator.")
                Divider().padding(.leading, 2)
                row(.replace, "Replace status bar",
                    "Draws a clean 9:41 and a full battery instead.")
            }
            .padding(.top, 22)

            Spacer(minLength: 24)

            HStack(spacing: 14) {
                Link("x", destination: URL(string: "https://x.com/gokhunguneyhan")!)
                Text("/").foregroundStyle(.tertiary)
                Link("github", destination:
                        URL(string: "https://github.com/gokhunguneyhan/invisibar")!)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    private func row(_ m: InvisibarMode, _ title: String, _ subtitle: String) -> some View {
        Button {
            pick(m)
            // Close on selecting, so the sheet is not in the way of the thing you
            // are about to record. Turning one OFF keeps it open.
            if mode == m { dismiss() }
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
