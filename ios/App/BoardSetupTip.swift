import SwiftUI

/// One-time tip on the empty board: how to keep reminders visible outside
/// the app. Dismissal is stored in UserDefaults via `@AppStorage(storageKey)`
/// and never resets on its own.
enum BoardSetupTip {
    static let storageKey = "boardSetupTipDismissed"

    struct Step: Hashable {
        let symbol: String
        let text: String
    }

    static let steps: [Step] = [
        Step(symbol: "lock.rectangle.on.rectangle", text: "Add the Lazy Man’s Reminders widget to your Lock Screen: touch and hold the Lock Screen, tap Customize, then Add Widgets."),
        Step(symbol: "bell.badge", text: "Allow Live Activities so your board stays on the Lock Screen (Settings → Lazy Man’s Reminders → Live Activities)."),
        Step(symbol: "app.badge", text: "Keep notifications on so reminders and board updates reach you."),
    ]

    /// Shown only on an empty board that finished loading without an error,
    /// and only until the user dismisses it once.
    static func shouldShow(
        hasLoaded: Bool,
        isBoardEmpty: Bool,
        hasError: Bool,
        isDismissed: Bool
    ) -> Bool {
        hasLoaded && isBoardEmpty && !hasError && !isDismissed
    }
}

struct BoardSetupTipCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Keep Your Board in View")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss tip")
                .padding(.trailing, -10)
                .padding(.vertical, -10)
            }
            ForEach(BoardSetupTip.steps, id: \.self) { step in
                Label {
                    Text(step.text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: step.symbol)
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}
