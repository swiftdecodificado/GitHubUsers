import GitHubAPI
import SwiftUI

struct UsersListView: View {
    @ObservedObject var viewModel: UsersListViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var layout: UsersLayout = .grid

    var body: some View {
        GeometryReader { geometry in
            let columns = columnCount(for: geometry.size.width)

            ScrollView {
                switch viewModel.state {
                case .idle, .loading:
                    UserListSkeleton(layout: layout, columns: columns)

                case .empty:
                    EmptyState(title: L10n.emptyUsers, symbol: "person.2")

                case let .failed(error):
                    ErrorState(error: error, retry: viewModel.retry)

                case .loaded:
                    if viewModel.isSearchEmpty {
                        EmptyState(title: L10n.emptySearch, symbol: "magnifyingglass")
                    } else {
                        UserCollection(
                            users: viewModel.filteredUsers,
                            layout: layout,
                            columns: columns,
                            paginationEnabled: viewModel.query.isEmpty,
                            loadNextPageIfNeeded: viewModel.loadNextPageIfNeeded
                        )

                        PaginationFooter(
                            isLoadingNextPage: viewModel.isLoadingNextPage,
                            paginationError: viewModel.paginationError,
                            refreshError: viewModel.refreshError,
                            retryPagination: viewModel.retryPagination,
                            retryRefresh: viewModel.refresh
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .refreshable { await viewModel.refresh() }
            .accessibilityIdentifier(layout == .grid ? "usersGrid" : "usersList")
            .accessibilityValue(String(columns))
        }
        .navigationTitle(L10n.users)
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $viewModel.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.search
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                layoutToggle
            }
        }
        .task { await viewModel.onAppear() }
    }

    private func columnCount(for width: CGFloat) -> Int {
        let horizontalPadding: CGFloat = 32
        let minimumColumnWidth: CGFloat = 170
        let spacing: CGFloat = 10
        let availableWidth = max(0, width - horizontalPadding)
        let fittingColumns = Int((availableWidth + spacing) / (minimumColumnWidth + spacing))

        return min(4, max(1, fittingColumns))
    }

    private var layoutToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                layout = layout == .grid ? .list : .grid
            }
        } label: {
            Image(systemName: layout == .grid ? "list.bullet" : "square.grid.2x2")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(layout == .grid ? L10n.list : L10n.grid)
        .accessibilityIdentifier("layoutToggle")
    }
}

#if DEBUG
    #Preview("Users") {
        NavigationStack {
            UsersListView(viewModel: UsersListViewModel(service: PreviewGitHubClient()))
        }
        .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
