import SwiftUI

/// Skeleton cards laid out like the real collection while the first page loads.
struct UserListSkeleton: View {
    let layout: UsersLayout
    let columns: Int

    var body: some View {
        let container = layout.container(columns: columns, listSpacing: 12)

        return container {
            ForEach(0 ..< 8) { index in
                Skeleton()
                    .frame(height: layout == .grid ? UserCardMetrics.waterfallHeight(for: index) : 76)
            }
        }
        .padding(.vertical, 10)
        .accessibilityLabel(L10n.loading)
    }
}

#if DEBUG
    #Preview("User List Skeleton") {
        ScrollView {
            UserListSkeleton(layout: .grid, columns: 2)
                .padding(.horizontal, 16)
        }
    }
#endif
