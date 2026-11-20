import SwiftUI

struct BoardDiscoveryNudgeCard: View {
    let nudge: BoardDiscoveryNudge
    let onDismiss: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    private var title: String {
        nudge == .web ? "Your board, everywhere" : "Agent access"
    }

    private var explanation: String {
        nudge == .web
            ? "Your board on this iPhone, the web, and the Lock Screen."
            : "Let an agent you authorized read, add, and complete reminders on your board."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Link(destination: nudge == .web ? LMRWeb.board : LMRWeb.agentAccess) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .tint(.primary)
                .accessibilityLabel(title)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(contrast == .increased ? .primary : .secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss tip")
            }
            Text(explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 1)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
