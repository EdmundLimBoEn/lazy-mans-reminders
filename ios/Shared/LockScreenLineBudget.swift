import Foundation
import UIKit
import SwiftUI

/// Measures how many compact reminder lines fit in the Lock Screen Live Activity
/// glass on this phone, caches the result in the App Group, and syncs to Supabase
/// so the web board uses the same capacity.
enum LockScreenLineBudget {
    static let pointSize: CGFloat = 15
    static let lineSpacing: CGFloat = 3
    /// Top + bottom padding inside the clear-glass banner.
    static let verticalPadding: CGFloat = 26
    static let fallbackMaxLines = 6
    static let minLines = 1
    static let maxLinesCap = 16

    private static let cacheKey = "lock-screen-max-lines"

    /// Last measured (or fallback) line budget for this device.
    static var cachedMaxLines: Int {
        guard
            let defaults = UserDefaults(suiteName: AppConfig.appGroupID),
            let value = defaults.object(forKey: cacheKey) as? Int,
            value >= minLines
        else {
            return fallbackMaxLines
        }
        return min(value, maxLinesCap)
    }

    /// Pure geometry → line count (unit-testable).
    static func computeMaxLines(
        screenHeight: CGFloat,
        pointSize: CGFloat = pointSize,
        lineSpacing: CGFloat = lineSpacing,
        verticalPadding: CGFloat = verticalPadding
    ) -> Int {
        // ActivityKit clamps Live Activity height; this tracks roughly with
        // phone height so Pro Max fits more lines than SE without guessing
        // a single global constant.
        let bannerMaxHeight = min(240, max(120, screenHeight * 0.20))
        let font = UIFont.systemFont(ofSize: pointSize, weight: .semibold)
        let rowHeight = ceil(font.lineHeight) + lineSpacing
        guard rowHeight > 0 else { return fallbackMaxLines }
        let usable = max(rowHeight, bannerMaxHeight - verticalPadding)
        let lines = Int(floor(usable / rowHeight))
        return min(maxLinesCap, max(minLines, lines))
    }

    /// Recompute from the current screen, write App Group cache, return the value.
    @discardableResult
    static func refreshLocalCache(
        screenHeight: CGFloat = UIScreen.main.bounds.height
    ) -> Int {
        let lines = computeMaxLines(screenHeight: screenHeight)
        if let defaults = UserDefaults(suiteName: AppConfig.appGroupID) {
            defaults.set(lines, forKey: cacheKey)
        }
        return lines
    }
}

enum LockScreenMarqueePolicy {
    static let overflowThreshold: CGFloat = 0.5

    static func shouldScroll(overflow: CGFloat, reduceMotion: Bool) -> Bool {
        overflow > overflowThreshold && !reduceMotion
    }
}

/// Presentation budgets are independent of the persisted board capacity.
/// ActivityKit may truncate surfaces taller than 160pt; the Island also reserves
/// space for the sensor region and its rounded bottom edge.
enum ReminderActivityLayout {
    enum Surface { case lockScreen, island }
    static func availableHeight(_ surface: Surface) -> CGFloat {
        surface == .lockScreen ? 134 : 96
    }
    static func rowHeight(pointSize: CGFloat) -> CGFloat {
        ceil(UIFont.systemFont(ofSize: pointSize, weight: .semibold).lineHeight)
    }
    static func lineLimit(pointSize: CGFloat, surface: Surface) -> Int {
        max(1, Int((availableHeight(surface) + LockScreenLineBudget.lineSpacing)
            / (rowHeight(pointSize: pointSize) + LockScreenLineBudget.lineSpacing)))
    }
}

/// Shared by the native widget and rendered-layout regression checks.
struct ReminderActivityLinesView: View {
    let lines: [String]
    let surface: ReminderActivityLayout.Surface
    @ScaledMetric(relativeTo: .subheadline) private var pointSize = LockScreenLineBudget.pointSize

    var body: some View {
        let limit = ReminderActivityLayout.lineLimit(pointSize: pointSize, surface: surface)
        let display = ReminderActivityPresentation.surfaceLines(lines, limit: limit)
        VStack(alignment: .leading, spacing: LockScreenLineBudget.lineSpacing) {
            ForEach(Array(display.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: pointSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: ReminderActivityLayout.rowHeight(pointSize: pointSize))
            }
        }
        .padding(.horizontal, surface == .island ? 14 : 0)
    }
}
