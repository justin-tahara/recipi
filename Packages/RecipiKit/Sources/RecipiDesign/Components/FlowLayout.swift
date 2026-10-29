import SwiftUI

/// Lays views out left to right and wraps onto new lines, like words.
/// Used for rows of tag pills.
public struct FlowLayout: Layout {
    let spacing: CGFloat

    public init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(width: bounds.width, subviews: subviews).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: Self.proposal(for: subview, width: bounds.width)
            )
        }
    }

    /// Each view at its natural size, unless that's wider than the row: then
    /// it gets the row's width and wraps (or truncates) to fit, instead of
    /// running off the edge at large text sizes.
    private static func proposal(for subview: LayoutSubview, width: CGFloat) -> ProposedViewSize {
        let natural = subview.sizeThatFits(.unspecified)
        return natural.width > width ? ProposedViewSize(width: width, height: nil) : .unspecified
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(Self.proposal(for: subview, width: width))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (positions, CGSize(width: widest, height: y + rowHeight))
    }
}
