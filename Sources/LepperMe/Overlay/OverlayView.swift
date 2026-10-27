import AppKit
import SwiftUI

// MARK: - Overlay

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    let dimming: Double
    /// The screen this copy of the overlay covers. The view is pinned to exactly this size.
    let screenSize: CGSize
    /// Dev snapshots: no live blur, content already visible.
    var snapshot = false
    @State private var appeared = false

    /// Content is designed for ~900 × 760 pt; shrink on small screens, grow a little on big ones.
    private var contentScale: CGFloat {
        min(1.25, max(0.6, min(screenSize.height / 900, screenSize.width / 760)))
    }

    var body: some View {
        ZStack {
            if !snapshot { VisualEffectBlur() }
            Theme.backgroundOverlay.opacity(dimming)
            AuroraBackground(completed: model.phase == .completed, reduceMotion: model.reduceMotion)
                .opacity(0.55)
            RadialGradient(
                colors: [.clear, Theme.backgroundCanvas.opacity(0.7)],
                center: .center,
                startRadius: min(screenSize.width, screenSize.height) * 0.25,
                endRadius: max(screenSize.width, screenSize.height) * 0.75
            )

            content
                .fixedSize()
                .scaleEffect(contentScale)
                .scaleEffect(model.phase == .leaving ? 0.97 : 1)
                .opacity(model.phase == .leaving ? 0 : 1)
                .blur(radius: model.phase == .leaving ? 6 : 0)
                .animation(.easeIn(duration: 0.35), value: model.phase)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            RevelWordmark()
                .frame(height: 18)
                .opacity(0.35)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 32)
                .entrance(isAppeared, delay: 0.7)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .clipped()
        .ignoresSafeArea()
        .onAppear {
            appeared = true
        }
    }

    private var isAppeared: Bool { appeared || snapshot }

    private var content: some View {
        VStack(spacing: 0) {
            KindBadge(kind: model.kind)
                .entrance(isAppeared, delay: 0.05)

            BreakRing(model: model)
                .frame(width: 260, height: 260)
                .padding(.top, Theme.Space.s32)
                .entrance(isAppeared, delay: 0.15, scale: 0.85)

            CountdownText(model: model)
                .padding(.top, Theme.Space.s24)
                .opacity(model.phase == .completed ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: model.phase)
                .entrance(isAppeared, delay: 0.22)

            VStack(spacing: Theme.Space.s12) {
                Text(model.phase == .completed ? "\(model.kind.title) beendet" : model.kind.title)
                    .font(Theme.font(36, .semibold))
                    .tracking(-1.2)
                    .foregroundStyle(Theme.contentPrimary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: model.phase)
                Text(model.phase == .completed ? model.completedMessage : model.message)
                    .font(Theme.font(18))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.contentSubdued)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Theme.Space.s16)
            .entrance(isAppeared, delay: 0.28)

            HStack(spacing: Theme.Space.s12) {
                if model.allowSnooze {
                    Button("In \(model.snoozeMinutes) Min. erinnern") { model.onSnooze() }
                        .buttonStyle(RButtonStyle(kind: .secondary, large: true))
                }
                Button("Überspringen") { model.onSkip() }
                    .buttonStyle(RButtonStyle(kind: .secondary, large: true))
            }
            .padding(.top, Theme.Space.s48)
            .opacity(model.phase == .completed ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: model.phase)
            .entrance(isAppeared, delay: 0.45)

            Text("Esc überspringt")
                .font(Theme.caption)
                .foregroundStyle(Theme.contentDisabled)
                .padding(.top, Theme.Space.s16)
                .opacity(model.phase == .completed ? 0 : 1)
                .entrance(isAppeared, delay: 0.55)
        }
        .padding(Theme.Space.s48)
    }
}

/// Remaining time under the ring, e.g. "0:18".
private struct CountdownText: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = model.remaining(at: context.date)
            Text(Self.format(remaining))
                .font(Theme.font(40, .semibold).monospacedDigit())
                .tracking(-1.2)
                .foregroundStyle(Theme.contentPrimary)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: Int(ceil(remaining)))
        }
        .accessibilityLabel("Verbleibende Zeit")
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Small label above the ring: icon + reminder type.
private struct KindBadge: View {
    let kind: ReminderKind

    var body: some View {
        HStack(spacing: Theme.Space.s8) {
            Image(systemName: kind.symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(kind.badge)
                .font(Theme.bodyMediumStrong)
        }
        .foregroundStyle(Theme.contentPrimary)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Capsule().fill(Theme.backgroundElevated.opacity(0.7)))
        .overlay(Capsule().strokeBorder(Theme.brandGradient, lineWidth: 1).opacity(0.9))
    }
}

/// Progress ring with brand gradient and glow. Morphs into a check mark when the break is done.
private struct BreakRing: View {
    @ObservedObject var model: OverlayModel
    @State private var breathe = false
    @State private var checkTrim: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: model.phase != .running)) { context in
            // Ring empties while the break runs, then fills up green when it's done.
            let progress = model.phase == .running ? 1 - model.progress(at: context.date) : 1

            ZStack {
                // Soft halo that breathes (8 s cycle).
                Circle()
                    .fill(Theme.accent.opacity(model.phase == .completed ? 0 : 0.18))
                    .blur(radius: 40)
                    .scaleEffect(breathe ? 1.12 : 0.9)

                Circle()
                    .stroke(Theme.Grey.g0.opacity(0.08), lineWidth: 6)

                // Glow layer + crisp layer.
                ring(progress: progress)
                    .blur(radius: 10)
                    .opacity(0.8)
                ring(progress: progress)

                if model.phase == .completed {
                    CheckMark()
                        .trim(from: 0, to: checkTrim)
                        .stroke(Theme.success, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .frame(width: 84, height: 64)
                        .shadow(color: Theme.success.opacity(0.6), radius: 12)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                } else {
                    // Each break type has its own animation in the ring's center.
                    Group {
                        switch model.kind {
                        case .eyes: EyeAnimation(reduceMotion: model.reduceMotion)
                        case .rest: BreathingAnimation(reduceMotion: model.reduceMotion)
                        case .posture: PostureAnimation(reduceMotion: model.reduceMotion)
                        }
                    }
                    .frame(width: 210, height: 210)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: model.phase)
        }
        .onAppear {
            guard !model.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onReceive(model.$phase) { phase in
            if phase == .completed {
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) { checkTrim = 1 }
            }
        }
    }

    private func ring(progress: Double) -> some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                model.phase == .completed ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.ringGradient),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}

private struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Aurora

/// Slowly drifting blobs in the revel8 gradient colors. Static with Reduce Motion.
struct AuroraBackground: View {
    let completed: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                let size = max(geo.size.width, geo.size.height) * 0.55
                ZStack {
                    blob(Theme.Blue.b400, size: size, geo: geo, t: t, speed: 0.050, phase: 0.0)
                    blob(Theme.purple600, size: size * 0.9, geo: geo, t: t, speed: 0.037, phase: 2.1)
                    blob(Theme.red600, size: size * 0.75, geo: geo, t: t, speed: 0.043, phase: 4.2)
                    blob(Theme.Green.g500, size: size * 1.1, geo: geo, t: t, speed: 0.03, phase: 1.0)
                        .opacity(completed ? 0.9 : 0)
                        .animation(.easeInOut(duration: 1.2), value: completed)
                }
                .blur(radius: 140)
            }
        }
        .drawingGroup()
    }

    private func blob(_ color: Color, size: CGFloat, geo: GeometryProxy, t: Double, speed: Double, phase: Double) -> some View {
        let x = geo.size.width * (0.5 + 0.32 * sin(t * speed * 2 * .pi + phase))
        let y = geo.size.height * (0.5 + 0.28 * cos(t * speed * 1.3 * 2 * .pi + phase * 1.7))
        return Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(x: x, y: y)
            .opacity(0.6)
    }
}

// MARK: - Entrance animation

private struct Entrance: ViewModifier {
    let appeared: Bool
    let delay: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .scaleEffect(appeared ? 1 : scale)
            .blur(radius: appeared ? 0 : 10)
            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

extension View {
    func entrance(_ appeared: Bool, delay: Double, scale: CGFloat = 1) -> some View {
        modifier(Entrance(appeared: appeared, delay: delay, scale: scale))
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Pre-warning

@MainActor
final class PreWarningModel: ObservableObject {
    let kind: ReminderKind
    let endDate: Date
    let lead: TimeInterval
    @Published var visible = false

    init(kind: ReminderKind, seconds: Int) {
        self.kind = kind
        self.lead = TimeInterval(seconds)
        self.endDate = Date().addingTimeInterval(TimeInterval(seconds))
    }
}

/// Compact pill that hangs at the mouse pointer and travels with it until the break starts.
/// Click-through by design: skipping and snoozing happen in the overlay (buttons or Esc).
struct PreWarningView: View {
    static let shadowPadding: CGFloat = 28
    @ObservedObject var model: PreWarningModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let left = max(0, model.endDate.timeIntervalSince(context.date))
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Theme.Grey.g0.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: model.lead > 0 ? left / model.lead : 0)
                        .stroke(Theme.ringGradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: model.kind.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.contentPrimary)
                }
                .frame(width: 26, height: 26)

                Text("\(model.kind.title) in \(Int(ceil(left))) s")
                    .font(Theme.bodyMediumStrong.monospacedDigit())
                    .foregroundStyle(Theme.contentPrimary)
                    .fixedSize()
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .frame(height: 42)
            .background(Capsule().fill(Theme.backgroundCanvas.opacity(0.94)))
            .overlay(Capsule().strokeBorder(Theme.borderPrimary, lineWidth: 1))
            .shadow(color: Theme.backgroundCanvas.opacity(0.4), radius: 18, y: 8)
        }
        .padding(PreWarningView.shadowPadding) // room for the soft shadow inside the panel
        // Pops out of the pointer: grows from the top-left corner, which sits at the cursor.
        .scaleEffect(model.visible ? 1 : 0.6, anchor: .topLeading)
        .opacity(model.visible ? 1 : 0)
        .blur(radius: model.visible ? 0 : 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.visible)
        .environment(\.colorScheme, .dark)
    }
}
