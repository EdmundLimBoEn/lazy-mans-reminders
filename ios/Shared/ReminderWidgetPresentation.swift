import Foundation
import WidgetKit

enum ReminderWidgetPresentation {
    static func spacing(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .accessoryInline, .accessoryRectangular: return 2
        case .systemSmall, .systemMedium: return 6
        default: return 8
        }
    }

    static func lineLimit(
        for family: WidgetFamily,
        lineHeight: CGFloat? = nil,
        headerHeight: CGFloat = 15,
        showsHeader: Bool = true
    ) -> Int {
        let lineHeight = lineHeight ?? (family == .accessoryRectangular ? 15 : 20)
        switch family {
        case .accessoryInline: return 1
        case .accessoryRectangular:
            // Accessory rectangular widgets have roughly 60pt of usable height.
            return min(3, max(1, Int(62 / (max(15, ceil(lineHeight)) + 2))))
        case .systemSmall, .systemMedium:
            // Both families share the short height. Budget for the smallest
            // phone: header + rows + every gap, including the trailing Spacer.
            // Default sizes: 15 + 4 * 20 + 5 * 6 = 125pt, below 130pt.
            let gap = spacing(for: family)
            let available: CGFloat = showsHeader ? 130 - max(15, ceil(headerHeight)) - gap : 130
            return min(4, max(1, Int(available / (max(20, ceil(lineHeight)) + gap))))
        default: return 6
        }
    }
}
