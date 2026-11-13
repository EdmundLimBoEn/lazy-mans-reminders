import SwiftUI
import UIKit

@MainActor
struct AppIconPickerSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var selection = AppIconSelection(client: UIApplication.shared)

    var body: some View {
        Section {
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
                        iconLabel(for: option)
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
                .accessibilityLabel(iconLabel(for: option))
                .accessibilityAddTraits(selection.selected == option ? .isSelected : [])
                .disabled(!selection.supportsAlternateIcons || selection.isChanging)
            }
            if selection.isChanging {
                ProgressView()
                    .accessibilityLabel("Changing app icon")
            }
        } header: {
            Text("App Icon")
        } footer: {
            if !selection.supportsAlternateIcons {
                Text("App icons can’t be changed on this device.")
                    .accessibilityAddTraits(.updatesFrequently)
            } else if selection.hasError {
                Text("Couldn’t change the icon. Try again.")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .onAppear { selection.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { selection.refresh() }
        }
    }

    private func iconLabel(for option: AppIconOption) -> Text {
        switch option {
        case .default: return Text("Default")
        case .minimal: return Text("Minimal")
        case .bold: return Text("Bold")
        }
    }
}
