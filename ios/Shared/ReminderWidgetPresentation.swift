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
        lineHeight: CGFloat = 20,
        headerHeight: CGFloat = 15
    ) -> Int {
        switch family {
        case .accessoryInline: return 1
        case .accessoryRectangular: return 3
        case .systemSmall, .systemMedium:
            // Both families share the short height. Budget for the smallest
            // phone: header + rows + every gap, including the trailing Spacer.
            // Default sizes: 15 + 4 * 20 + 5 * 6 = 125pt, below 130pt.
            let gap = spacing(for: family)
            let available = 130 - max(15, ceil(headerHeight)) - gap
            return min(4, max(1, Int(available / (max(20, ceil(lineHeight)) + gap))))
        default: return 6
        }
    }
}
