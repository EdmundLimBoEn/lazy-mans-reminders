import SwiftUI

struct ClipboardOfferCard: View {
    let onPaste: ([String]) -> Void
    let onDismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text("Add from clipboard?")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PasteButton(payloadType: String.self, onPaste: onPaste)
                    .labelStyle(.iconOnly)
                    .tint(.primary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Add reminder")
                    .accessibilityHint("Adds a new reminder from the clipboard")
            }
            .frame(minHeight: 44)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss tip")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(contrast == .increased ? Color.primary : Color(.separator), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add from clipboard?")
    }
}
