import SwiftUI

struct ProfileStats: View {
    let stats: [UserStat]

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                verticalStats
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        statsContent(minimumWidth: 88)
                    }

                    verticalStats
                }
            }
        }
        .padding(20)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
    }

    private var verticalStats: some View {
        VStack(alignment: .leading, spacing: 16) {
            statsContent()
        }
    }

    @ViewBuilder
    private func statsContent(minimumWidth: CGFloat? = nil) -> some View {
        ForEach(stats) { stat in
            VStack(spacing: 6) {
                Text(stat.value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: stat.value)

                Text(L10n.stat(stat.kind))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .overflowWrap()
            }
            .frame(minWidth: minimumWidth, maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}

#if DEBUG
    #Preview("Profile Stats") {
        ProfileStats(stats: [
            .init(kind: .repositories, value: "100"),
            .init(kind: .followers, value: "23.1K"),
            .init(kind: .following, value: "11")
        ])
        .padding()
    }
#endif
