import SwiftUI

/// Each item is placed in the column with the smallest measured accumulated height.
struct WaterfallGrid: Layout {
    var columns: Int
    var spacing: CGFloat = 10

    struct Cache {
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }

    func makeCache(subviews _: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 320
        let count = max(1, columns)
        let cellWidth = max(0, (width - CGFloat(count - 1) * spacing) / CGFloat(count))
        var heights = Array(repeating: CGFloat.zero, count: count)

        cache.frames = subviews.map { subview in
            let column = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            let height = subview.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
            let frame = CGRect(
                x: CGFloat(column) * (cellWidth + spacing),
                y: heights[column],
                width: cellWidth,
                height: height
            )

            heights[column] += height + spacing
            return frame
        }

        cache.size = CGSize(width: width, height: max(0, (heights.max() ?? 0) - spacing))
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        if cache.frames.count != subviews.count || cache.size.width != bounds.width {
            _ = sizeThatFits(
                proposal: ProposedViewSize(width: bounds.width, height: nil),
                subviews: subviews,
                cache: &cache
            )
        }

        for (index, subview) in subviews.enumerated() {
            let frame = cache.frames[index]

            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}

#if DEBUG
    #Preview("Waterfall Grid") {
        ScrollView {
            WaterfallGrid(columns: 2) {
                ForEach(1 ... 6, id: \.self) { id in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)
                        .frame(height: CGFloat(120 + id % 3 * 38))
                        .overlay {
                            Text("Item \(id)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .padding()
        }
    }
#endif
