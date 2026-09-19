import GitHubAPI
import SwiftUI

struct UsersListView: View {
    @ObservedObject var vm: UsersListViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var layout: UsersLayout = .grid

    var body: some View {
        GeometryReader { geometry in
            let columns = columnCount(for: geometry.size.width)

            ScrollView {
                switch vm.state {
                case .idle, .loading:
                    UserListSkeleton(layout: layout, columns: columns)

                case .empty:
                    EmptyState(title: L10n.emptyUsers, symbol: "person.2")

                case let .failed(error):
                    ErrorState(error: error, retry: vm.retry)

                case .loaded:
                    if vm.isSearchEmpty {
                        EmptyState(title: L10n.emptySearch, symbol: "magnifyingglass")
                    } else {
                        UserCollection(
                            users: vm.filteredUsers,
                            layout: layout,
                            columns: columns,
                            paginationEnabled: vm.query.isEmpty,
                            loadNextPageIfNeeded: vm.loadNextPageIfNeeded,
                        )

                        PaginationFooter(
                            isLoadingNextPage: vm.isLoadingNextPage,
                            paginationError: vm.paginationError,
                            refreshError: vm.refreshError,
                            retryPagination: vm.retryPagination,
                            retryRefresh: vm.refresh,
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .refreshable { await vm.refresh() }
            .accessibilityIdentifier(layout == .grid ? "usersGrid" : "usersList")
            .accessibilityValue(String(columns))
        }
        .navigationTitle(L10n.users)
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $vm.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.search,
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                layoutToggle
            }
        }
        .task { await vm.onAppear() }
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
            UsersListView(vm: UsersListViewModel(service: PreviewGitHubClient()))
        }
        .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
