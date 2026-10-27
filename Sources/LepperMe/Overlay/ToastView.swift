import SwiftUI

/// Short, silent status message, e.g. "Meeting erkannt". Never takes focus or clicks.
@MainActor
final class ToastModel: ObservableObject {
    let symbol: String
    let title: String
    let message: String
    @Published var visible = false

    init(symbol: String, title: String, message: String) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }
}

struct ToastView: View {
    static let shadowPadding: CGFloat = 32
    @ObservedObject var model: ToastModel

    var body: some View {
        HStack(spacing: Theme.Space.s12) {
            ZStack {
                Circle().fill(Theme.brandGradient)
                Image(systemName: model.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.contentPrimary)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(Theme.bodyMediumStrong)
                    .foregroundStyle(Theme.contentPrimary)
                Text(model.message)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.contentSubdued)
            }
            .fixedSize()
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .frame(height: 52)
        .background(Capsule().fill(Theme.backgroundCanvas.opacity(0.94)))
        .overlay(Capsule().strokeBorder(Theme.borderPrimary, lineWidth: 1))
        .shadow(color: Theme.backgroundCanvas.opacity(0.35), radius: 24, y: 12)
        .padding(ToastView.shadowPadding)
        .offset(y: model.visible ? 0 : -24)
        .opacity(model.visible ? 1 : 0)
        .blur(radius: model.visible ? 0 : 4)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: model.visible)
        .environment(\.colorScheme, .dark)
    }
}
