import Combine
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable, Sendable {
    case `default`
    case minimal
    case bold

    var id: Self { self }

    var alternateIconName: String? {
        switch self {
        case .default: return nil
        case .minimal: return "AppIcon-Minimal"
        case .bold: return "AppIcon-Bold"
        }
    }

    var previewImageName: String {
        switch self {
        case .default: return "AppIconPreview-Default"
        case .minimal: return "AppIconPreview-Minimal"
        case .bold: return "AppIconPreview-Bold"
        }
    }

    init?(alternateIconName: String?) {
        guard let option = Self.allCases.first(where: { $0.alternateIconName == alternateIconName }) else {
            return nil
        }
        self = option
    }
}

@MainActor
protocol AppIconClient: AnyObject {
    var alternateIconName: String? { get }
    var supportsAlternateIcons: Bool { get }
    func setAlternateIconName(_ name: String?) async throws
}

extension UIApplication: AppIconClient {}

@MainActor
final class AppIconSelection: ObservableObject {
    @Published private(set) var selected: AppIconOption?
    @Published private(set) var supportsAlternateIcons = false
    @Published private(set) var isChanging = false
    @Published private(set) var hasError = false

    private let client: any AppIconClient

    init(client: any AppIconClient) {
        self.client = client
        refresh()
    }

    func refresh() {
        selected = AppIconOption(alternateIconName: client.alternateIconName)
        supportsAlternateIcons = client.supportsAlternateIcons
    }

    func select(_ option: AppIconOption) async {
        guard !isChanging else { return }
        refresh()
        guard supportsAlternateIcons else { return }
        hasError = false
        guard selected != option else { return }
        isChanging = true
        defer {
            // The system owns persistence; only show what it actually selected.
            refresh()
            isChanging = false
        }
        do {
            try await client.setAlternateIconName(option.alternateIconName)
        } catch {
            hasError = true
        }
    }
}
