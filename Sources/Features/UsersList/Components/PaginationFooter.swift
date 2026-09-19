import GitHubAPI
import SwiftUI

/// Progress and errors shown below the loaded users: next page, pagination failure and refresh failure.
struct PaginationFooter: View {
    let isLoadingNextPage: Bool
    let paginationError: GitHubAPIError?
    let refreshError: GitHubAPIError?
    let retryPagination: @MainActor () async -> Void
    let retryRefresh: @MainActor () async -> Void

    var body: some View {
        if isLoadingNextPage {
            ProgressView()
                .padding()
                .accessibilityLabel(L10n.loading)
        }

        if let paginationError {
            ErrorState(error: paginationError, retry: retryPagination)
        }

        if let refreshError {
            ErrorState(error: refreshError, retry: retryRefresh)
        }
    }
}

#if DEBUG
    #Preview("Pagination Footer — Loading") {
        PaginationFooter(
            isLoadingNextPage: true,
            paginationError: nil,
            refreshError: nil,
            retryPagination: {},
            retryRefresh: {},
        )
        .padding()
    }

    #Preview("Pagination Footer — Error") {
        PaginationFooter(
            isLoadingNextPage: false,
            paginationError: .network,
            refreshError: nil,
            retryPagination: {},
            retryRefresh: {},
        )
        .padding()
    }
#endif
