import GitHubAPI
import SwiftUI

enum UsersLayout: String, Sendable {
    case grid, list

    func container(columns: Int, listSpacing: CGFloat) -> AnyLayout {
        switch self {
        case .grid:
            AnyLayout(WaterfallGrid(columns: columns))
        case .list:
            AnyLayout(VStackLayout(spacing: listSpacing))
        }
    }
}

struct UserCollection: View {
    let users: [GitHubUser]
    let layout: UsersLayout
    let columns: Int
    var paginationEnabled = true
    let loadNextPageIfNeeded: @MainActor (GitHubUser) async -> Void

    @ViewBuilder
    var body: some View {
        switch layout {
        case .grid:
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                    userLink(user, index: index)
                }
            }

        case .list:
            LazyVStack(spacing: 0) {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                    userLink(user, index: index)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: max(1, columns),
        )
    }

    private func userLink(_ user: GitHubUser, index: Int) -> some View {
        NavigationLink(value: user) {
            switch layout {
            case .grid:
                UserCard(user: user)
            case .list:
                UserRow(user: user)
            }
        }
        .buttonStyle(CardPressStyle())
        .id(user.id)
        .accessibilityIdentifier("user-\(user.id)")
        .modifier(CardEntrance(index: index))
        .onAppear {
            guard paginationEnabled else {
                return
            }

            Task {
                await loadNextPageIfNeeded(user)
            }
        }
    }
}

#if DEBUG
    #Preview("User Collection") {
        NavigationStack {
            ScrollView {
                UserCollection(
                    users: [.preview],
                    layout: .grid,
                    columns: 2,
                    loadNextPageIfNeeded: { _ in },
                )
                .padding(.horizontal, 16)
            }
        }
        .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
