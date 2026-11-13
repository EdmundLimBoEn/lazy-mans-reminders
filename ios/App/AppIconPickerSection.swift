import SwiftUI
import UIKit

@MainActor
struct AppIconPickerSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var selection = AppIconSelection(client: UIApplication.shared)

    var body: some View {
        Section {
            // Image rows keep the choices distinguishable until Edmund supplies copy.
            ForEach(AppIconOption.allCases) { option in
                Button {
                    Task { await selection.select(option) }
                } label: {
                    HStack(spacing: 14) {
                        Image(option.previewImageName)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .accessibilityHidden(true)
                        Text("[PLACEHOLDER - Edmund to write]")
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        if selection.selected == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.primary)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("[PLACEHOLDER - Edmund to write]")
                .accessibilityAddTraits(selection.selected == option ? .isSelected : [])
                .disabled(!selection.supportsAlternateIcons || selection.isChanging)
            }
            if selection.isChanging {
                ProgressView()
                    .accessibilityLabel("[PLACEHOLDER - Edmund to write]")
            }
        } header: {
            Text("[PLACEHOLDER - Edmund to write]")
        } footer: {
            if !selection.supportsAlternateIcons || selection.hasError {
                Text("[PLACEHOLDER - Edmund to write]")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .onAppear { selection.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { selection.refresh() }
        }
    }
}
