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
    func changeIcon(to name: String?, completion: @escaping @MainActor (Error?) -> Void)
}

extension UIApplication: AppIconClient {
    func changeIcon(to name: String?, completion: @escaping @MainActor (Error?) -> Void) {
        setAlternateIconName(name) { error in
            Task { @MainActor in completion(error) }
        }
    }
}

@MainActor
final class AppIconSelection: ObservableObject {
    @Published private(set) var selected: AppIconOption?
    @Published private(set) var supportsAlternateIcons = false
    @Published private(set) var isChanging = false
    @Published private(set) var hasError = false

    private let client: any AppIconClient
    private var pendingRequest: (id: UUID, option: AppIconOption)?

    init(client: any AppIconClient) {
        self.client = client
        refresh()
    }

    func refresh() {
        selected = AppIconOption(alternateIconName: client.alternateIconName)
        supportsAlternateIcons = client.supportsAlternateIcons
        if let pendingRequest, selected == pendingRequest.option {
            self.pendingRequest = nil
            isChanging = false
            hasError = false
        }
    }

    func select(_ option: AppIconOption) {
        refresh()
        guard !isChanging else { return }
        guard supportsAlternateIcons else { return }
        hasError = false
        guard selected != option else { return }
        let requestID = UUID()
        pendingRequest = (requestID, option)
        isChanging = true
        client.changeIcon(to: option.alternateIconName) { [weak self] _ in
            guard let self, pendingRequest?.id == requestID else { return }
            // UIKit can report an error after applying the icon; system state is authoritative.
            self.refresh()
            self.hasError = self.selected != option
            self.pendingRequest = nil
            self.isChanging = false
        }
    }
}
