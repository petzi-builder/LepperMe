import AppKit
import SwiftUI

// One hero animation per reminder type. All are driven by a TimelineView clock, so they
// render deterministically in snapshots and freeze cleanly with Reduce Motion.

// MARK: - Augenpause: blinking eye, rings receding into the distance

struct EyeAnimation: View {
    var reduceMotion = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let t = reduceMotion ? 1.0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                // Depth rings: start wide and fade into the center, like focusing on something far away.
                ForEach(0..<4, id: \.self) { i in
                    let phase = (t / 3.2 + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Theme.Blue.b300.opacity(0.55), lineWidth: 1.5)
                        .scaleEffect(1 - phase * 0.85)
                        .opacity(sin(phase * .pi) * 0.8)
                }

                EyeGlyph(openness: Self.openness(at: t), lookAhead: Self.drift(at: t))
                    .frame(width: 128, height: 70)
            }
        }
    }

    /// Blink every 4.5 s: a quick close/open over 0.24 s.
    static func openness(at t: Double) -> CGFloat {
        let p = t.truncatingRemainder(dividingBy: 4.5)
        guard p < 0.24 else { return 1 }
        return CGFloat(abs(cos(p / 0.24 * .pi)))
    }

    /// The pupil drifts slightly, never staring.
    static func drift(at t: Double) -> CGSize {
        CGSize(width: sin(t * 0.7) * 4, height: cos(t * 0.5) * 2)
    }
}

private struct EyeGlyph: View {
    let openness: CGFloat
    let lookAhead: CGSize

    var body: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(Theme.backgroundCanvas)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 6, height: 6)
                    .offset(x: 7, y: -7)
            }
            .offset(lookAhead)
            // Clip with the full eye outline, not the iris' own small frame.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(EyeShape())

            EyeShape()
                .stroke(Theme.contentPrimary, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
        }
        .scaleEffect(x: 1, y: max(0.06, openness))
        .shadow(color: Theme.Blue.b400.opacity(0.6), radius: 16)
    }
}

private struct EyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.5))
        p.closeSubpath()
        return p
    }
}

// MARK: - Pause: breathing orb (4 s in, 4 s out)

struct BreathingAnimation: View {
    var reduceMotion = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let t = reduceMotion ? 2.0 : context.date.timeIntervalSinceReferenceDate
            let cycle = t.truncatingRemainder(dividingBy: 8)
            let breath = 0.5 - 0.5 * cos(cycle / 8 * 2 * .pi) // 0 → 1 → 0
            let inhaling = cycle < 4

            ZStack {
                // Echo rings trail the orb.
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Theme.Blue.b300.opacity(0.25 - Double(i) * 0.1), lineWidth: 1.5)
                        .scaleEffect(0.62 + breath * 0.38 + CGFloat(i + 1) * 0.08)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Blue.b300, Theme.Blue.b500, Theme.purple600],
                            center: UnitPoint(x: 0.35, y: 0.3), startRadius: 4, endRadius: 120
                        )
                    )
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                    .shadow(color: Theme.Blue.b400.opacity(0.7), radius: 30)
                    .scaleEffect(0.55 + breath * 0.4)

                Text(inhaling ? "Einatmen" : "Ausatmen")
                    .font(Theme.bodyLargeStrong)
                    .foregroundStyle(Theme.contentPrimary)
                    .id(inhaling)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.6), value: inhaling)
            }
            .frame(width: 190, height: 190)
        }
    }
}

// MARK: - Haltung: one arrow rising calmly

/// A single arrow rises once (ease-out, ~1.4 s) and then floats gently, like straightening up.
struct PostureAnimation: View {
    var start = Date()
    var reduceMotion = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 10 : context.date.timeIntervalSince(start)
            let rise = Self.easeOut(min(1, max(0, elapsed / 1.4)))
            let float = elapsed > 1.4 ? sin((elapsed - 1.4) / 4 * 2 * .pi) * 3 : 0
            ZStack {
                // Soft glow that slowly breathes behind the arrow.
                Circle()
                    .fill(Theme.purple600.opacity(0.35))
                    .frame(width: 90, height: 90)
                    .blur(radius: 30)
                    .scaleEffect(0.9 + 0.1 * sin(elapsed / 4 * 2 * .pi))

                UpArrow()
                    .stroke(Theme.brandGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 52, height: 72)
                    .offset(y: 30 * (1 - rise) + float)
                    .opacity(rise)
            }
            .frame(width: 120, height: 120)
        }
    }

    private static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

private struct UpArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Stem
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 3))
        // Head
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.width / 2))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.width / 2))
        return p
    }
}

// MARK: - Posture HUD (non-blocking reminder in the middle of the screen)

@MainActor
final class PostureHUDModel: ObservableObject {
    @Published var visible = false
    let title = "Aufrecht sitzen"
    let message: String
    let reduceMotion: Bool
    var start = Date()

    init(message: String) {
        self.message = message
        self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

struct PostureHUDView: View {
    @ObservedObject var model: PostureHUDModel

    var body: some View {
        VStack(spacing: Theme.Space.s16) {
            PostureAnimation(start: model.start, reduceMotion: model.reduceMotion)
            VStack(spacing: 6) {
                Text(model.title)
                    .font(Theme.font(24, .semibold))
                    .tracking(-0.96)
                    .foregroundStyle(Theme.contentPrimary)
                Text(model.message)
                    .font(Theme.bodyMedium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.contentSubdued)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Space.s32)
        .padding(.vertical, Theme.Space.s32)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.backgroundCanvas.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Theme.borderPrimary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 40, y: 20)
        .padding(60) // room for the shadow inside the panel
        .scaleEffect(model.visible ? 1 : 0.85)
        .offset(y: model.visible ? 0 : 24)
        .opacity(model.visible ? 1 : 0)
        .blur(radius: model.visible ? 0 : 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: model.visible)
        .environment(\.colorScheme, .dark)
    }
}
