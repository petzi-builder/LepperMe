import SwiftUI

// MARK: - Buttons (revel8 Button: radius md, 14 / 600, height 40)

struct RButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .primary
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        RButton(configuration: configuration, kind: kind, large: large)
    }

    private struct RButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let large: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(large ? Theme.bodyLargeStrong : Theme.bodyMediumStrong)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, large ? Theme.Space.s24 : (kind == .ghost ? Theme.Space.s12 : Theme.Space.s16))
                .frame(height: large ? 48 : 36)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(kind == .secondary ? Theme.borderPrimary : .clear, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: hovering)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }

        private var foreground: Color {
            switch kind {
            case .primary: return Theme.buttonPrimaryContent
            case .secondary: return Theme.contentPrimary
            case .ghost: return hovering ? Theme.contentPrimary : Theme.contentSubdued
            }
        }

        private var background: Color {
            switch kind {
            case .primary: return hovering ? Theme.Grey.g100 : Theme.buttonPrimary
            case .secondary: return hovering ? Theme.Grey.g800 : Theme.buttonSecondary
            case .ghost: return hovering ? Theme.Grey.g0.opacity(0.08) : .clear
            }
        }
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    let title: String?
    let systemImage: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(spacing: Theme.Space.s8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(title)
                        .font(Theme.bodyMediumStrong)
                        .foregroundStyle(Theme.contentPrimary)
                }
                .padding(.horizontal, Theme.Space.s16)
                .padding(.top, Theme.Space.s16)
                .padding(.bottom, Theme.Space.s8)
            }
            content
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.backgroundRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.borderSubdued, lineWidth: 1)
        )
    }
}

/// One labeled row inside a card.
struct SettingRow<Control: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.s16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.bodyMedium)
                    .foregroundStyle(Theme.contentPrimary)
                if let hint {
                    Text(hint)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.contentSubdued)
                }
            }
            Spacer(minLength: Theme.Space.s8)
            control
        }
        .padding(.horizontal, Theme.Space.s16)
        .padding(.vertical, 10)
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.borderSubdued)
            .frame(height: 1)
            .padding(.leading, Theme.Space.s16)
    }
}

// MARK: - Value stepper ("–  20 Min.  +")

struct ValueStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let format: (Int) -> String

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            Text(format(value))
                .font(Theme.bodyMediumStrong.monospacedDigit())
                .foregroundStyle(Theme.contentPrimary)
                .frame(minWidth: 72)
                .contentTransition(.identity)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
            stepButton("plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.backgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.borderPrimary, lineWidth: 1)
        )
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Theme.contentPrimary : Theme.contentDisabled)
        .disabled(!enabled)
    }
}

// MARK: - Toggle (switch in brand blue)

struct RToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Theme.accent : Theme.Grey.g800)
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(Theme.Grey.g0)
                    .frame(width: 18, height: 18)
                    .padding(2)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Schalter"))
        .accessibilityValue(Text(configuration.isOn ? "An" : "Aus"))
    }
}

// MARK: - Segmented tabs

struct PillTabs<Tab: Hashable>: View {
    let tabs: [(Tab, String, String)] // value, title, SF Symbol
    @Binding var selection: Tab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.0) { tab, title, symbol in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                        Text(title).font(Theme.bodyMediumStrong)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .foregroundStyle(selection == tab ? Theme.buttonPrimaryContent : Theme.contentSubdued)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.buttonPrimary)
                                .matchedGeometryEffect(id: "tab", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.backgroundRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.borderSubdued, lineWidth: 1)
        )
    }
}

// MARK: - Slider (gradient fill, white thumb)

struct RSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var width: CGFloat = 200
    @Environment(\.isEnabled) private var isEnabled
    @State private var dragging = false

    private let thumb: CGFloat = 18

    var body: some View {
        let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let travel = width - thumb
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.Grey.g800)
                .frame(height: 4)
            Capsule()
                .fill(Theme.brandGradient)
                .frame(width: thumb / 2 + travel * fraction, height: 4)
            Circle()
                .fill(Theme.Grey.g0)
                .frame(width: thumb, height: thumb)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .scaleEffect(dragging ? 1.15 : 1)
                .offset(x: travel * fraction)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
        }
        .frame(width: width, height: 24)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    dragging = true
                    let f = min(1, max(0, (drag.location.x - thumb / 2) / travel))
                    value = range.lowerBound + f * (range.upperBound - range.lowerBound)
                }
                .onEnded { _ in dragging = false }
        )
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(fraction * 100)) Prozent"))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }
}
