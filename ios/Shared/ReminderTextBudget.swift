import Foundation

/// Typography for a fixed-height surface. Keep room for two readable lines
/// (a wrapped reminder, or a reminder and overflow) before reducing type size.
struct ReminderTextBudget {
    let contentHeight: CGFloat
    let lineHeight: CGFloat
    let fontScale: CGFloat

    init(contentHeight: CGFloat, lineHeight: CGFloat, spacing: CGFloat, minimumLines: Int = 2) {
        self.contentHeight = contentHeight
        let requestedHeight = max(1, ceil(lineHeight))
        let count = max(1, minimumLines)
        let fittingHeight = max(1, floor((contentHeight - CGFloat(count - 1) * spacing) / CGFloat(count)))
        self.lineHeight = min(requestedHeight, fittingHeight)
        self.fontScale = self.lineHeight / requestedHeight
    }

    /// Wrapped Text has no inter-row VStack gaps, so it can use all the height.
    func lineLimit(displayedRows: Int) -> Int {
        displayedRows == 1 ? max(1, Int(floor(contentHeight / lineHeight))) : 1
    }
}
