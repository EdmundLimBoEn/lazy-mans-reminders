import SwiftUI

struct HillclimbRowProbe: ViewModifier {
    let id: UUID
    let text: String
    func body(content: Content) -> some View {
#if DEBUG
        if HillclimbDemo.isActive {
            content.background(GeometryReader { geometry in
                Color.clear.onAppear { HillclimbGeometry.shared.frames[id.uuidString] = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in HillclimbGeometry.shared.frames[id.uuidString] = frame }
            })
        } else { content }
#else
        content
#endif
    }
}
struct HillclimbComposerProbe: ViewModifier {
    func body(content: Content) -> some View {
#if DEBUG
        if HillclimbDemo.isActive {
            content.background(GeometryReader { geometry in
                Color.clear.onAppear { HillclimbGeometry.shared.frames["composer"] = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in HillclimbGeometry.shared.frames["composer"] = frame }
            })
        } else { content }
#else
        content
#endif
    }
}
#if DEBUG
import UIKit
@MainActor final class HillclimbGeometry {
    static let shared = HillclimbGeometry()
    var frames: [String: CGRect] = [:]
    var boardRetryAttempts = 0
    var boardCompletions = 0
    var boardMoves = 0
    var boardErrorAnnouncements: [String] = []
    weak var list: UICollectionView?
}
struct HillclimbGeometryExport: UIViewRepresentable {
    func makeUIView(context: Context) -> ExportView { ExportView() }
    func updateUIView(_ uiView: ExportView, context: Context) {}
    final class ExportView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isAccessibilityElement = true
            accessibilityIdentifier = "hillclimb.geometry"
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // UICollectionView's UIHostingConfiguration inherits UIKit traits, not
            // the outer SwiftUI dynamicTypeSize environment override.
            window?.traitOverrides.preferredContentSizeCategory =
                HillclimbDemo.argument("--hillclimb-size") == "XXXL" ? .extraExtraExtraLarge : .large
        }
        override var accessibilityValue: String? {
            get {
                var values = HillclimbGeometry.shared.frames.mapValues { [$0.minX, $0.minY, $0.width, $0.height] }
                if let mode = HillclimbDemo.mode {
                    values["fixtureCount"] = [Double(HillclimbDemo.reminders(for: mode).count), 0, 0, 0]
                }
                if let list = HillclimbGeometry.shared.list {
                    let viewport = list.convert(list.bounds, to: nil)
                    values["listViewport"] = [viewport.minX, viewport.minY, viewport.width, viewport.height]
                    var fadeHeight: CGFloat = 0
                    if #available(iOS 26.0, *), !list.bottomEdgeEffect.isHidden {
                        // UIKit exposes no effect bounds. Reject the whole viewport
                        // conservatively if an unmeasurable fade is reintroduced.
                        fadeHeight = viewport.height
                    }
                    values["bottomFade"] = [viewport.minX, viewport.maxY - fadeHeight, viewport.width, fadeHeight]
                    values["refreshState"] = [list.refreshControl?.isRefreshing == true ? 1 : 0, 0, 0, 0]
                }
                values["boardErrorAnnouncements"] = [Double(HillclimbGeometry.shared.boardErrorAnnouncements.count), 0, 0, 0]
                values["boardRetryAttempts"] = [Double(HillclimbGeometry.shared.boardRetryAttempts), 0, 0, 0]
                values["boardCompletions"] = [Double(HillclimbGeometry.shared.boardCompletions), 0, 0, 0]
                values["boardMoves"] = [Double(HillclimbGeometry.shared.boardMoves), 0, 0, 0]
                let auth = AuthManager.shared
                values["authState"] = [auth.session == nil ? 0 : 1, auth.isRestoringSession ? 1 : 0,
                                       auth.isSharedSessionReady ? 1 : 0, auth.isAuthenticating ? 1 : 0]
                if let window {
                    values["typeSize"] = [
                        UIFont.preferredFont(forTextStyle: .body, compatibleWith: window.traitCollection).pointSize,
                        UIFont.preferredFont(forTextStyle: .body, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize,
                        0, 0
                    ]
                    values["safeArea"] = [window.safeAreaInsets.left, window.safeAreaInsets.top,
                                          window.bounds.width - window.safeAreaInsets.left - window.safeAreaInsets.right,
                                          window.bounds.height - window.safeAreaInsets.top - window.safeAreaInsets.bottom]
                }
                guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            set {}
        }
    }
}
#endif

struct HillclimbTextProbe: ViewModifier {
    let id: UUID
    let text: String
    func body(content: Content) -> some View {
#if DEBUG
        if HillclimbDemo.isActive {
            content.background(GeometryReader { actual in
                Text(text).font(.body).kerning(-0.1)
                    .frame(width: actual.size.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { ideal in
                        Color.clear.onAppear { record(actual, ideal) }
                            .onChange(of: actual.frame(in: .global)) { _, _ in record(actual, ideal) }
                            .onChange(of: ideal.size) { _, _ in record(actual, ideal) }
                    })
                    .hidden().accessibilityHidden(true)
            })
        } else { content }
#else
        content
#endif
    }
#if DEBUG
    private func record(_ actual: GeometryProxy, _ ideal: GeometryProxy) {
        HillclimbGeometry.shared.frames["text-" + id.uuidString] = actual.frame(in: .global)
        HillclimbGeometry.shared.frames["ideal-" + id.uuidString] = CGRect(origin: .zero, size: ideal.size)
    }
#endif
}

struct HillclimbFrameProbe: ViewModifier {
    let key: String
    func body(content: Content) -> some View {
#if DEBUG
        if HillclimbDemo.isActive {
            content.background(GeometryReader { geometry in
                Color.clear.onAppear { HillclimbGeometry.shared.frames[key] = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in HillclimbGeometry.shared.frames[key] = frame }
            })
        } else { content }
#else
        content
#endif
    }
}

struct HillclimbCapacityProbe: ViewModifier {
    func body(content: Content) -> some View {
#if DEBUG
        if HillclimbDemo.isActive {
            content.background(GeometryReader { actual in
                Text("Board full — combine lines instead").font(.body)
                    .frame(width: actual.size.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(GeometryReader { ideal in
                        Color.clear.onAppear { record(actual, ideal) }
                            .onChange(of: actual.frame(in: .global)) { _, _ in record(actual, ideal) }
                            .onChange(of: ideal.size) { _, _ in record(actual, ideal) }
                    }).hidden().accessibilityHidden(true)
            })
        } else { content }
#else
        content
#endif
    }
#if DEBUG
    private func record(_ actual: GeometryProxy, _ ideal: GeometryProxy) {
        HillclimbGeometry.shared.frames["capacity"] = actual.frame(in: .global)
        HillclimbGeometry.shared.frames["capacityIdeal"] = CGRect(origin: .zero, size: ideal.size)
    }
#endif
}
