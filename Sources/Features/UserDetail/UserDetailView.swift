import GitHubAPI
import SwiftUI

struct UserDetailView: View {
    @StateObject private var viewModel: UserDetailViewModel
    @Namespace private var viewerNamespace
    @State private var showingAvatar = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var offset: CGFloat = 0

    init(user: GitHubUser, service: any GitHubClientProtocol, cache: GitHubUserCache = GitHubUserCache()) {
        _viewModel = StateObject(wrappedValue: UserDetailViewModel(user: user, service: service, cache: cache))
    }

    private var collapse: CGFloat {
        min(1, max(0, -offset / 160))
    }

    var body: some View {
        ZStack {
            profileScroll
                .accessibilityHidden(showingAvatar)

            if showingAvatar {
                AvatarViewer(
                    url: viewModel.avatarURL,
                    login: viewModel.login,
                    namespace: viewerNamespace,
                    dismiss: closeAvatar
                )
                .zIndex(2)
                .transition(.opacity)
            }
        }
        .background(.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(showingAvatar ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                collapsedTitle
            }

            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-UITEST_MOCK") {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await viewModel.refreshAfterBackground()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel(L10n.refresh)
                        .accessibilityIdentifier("simulateBackgroundReturn")
                    }
                }
            #endif
        }
        .tint(collapse < 0.5 ? .white : .primary)
        .task { await viewModel.onAppear() }
        .onReturnFromBackground { await viewModel.refreshAfterBackground() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("userDetail")
    }

    private var profileScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileHeader(
                    avatarURL: viewModel.avatarURL,
                    login: viewModel.login,
                    offset: offset,
                    isAvatarOpen: showingAvatar,
                    namespace: viewerNamespace,
                    openAvatar: { showingAvatar = true }
                )

                profileContent
            }
            .frame(maxWidth: .infinity)
        }
        .coordinateSpace(name: "detailScroll")
        .onPreferenceChange(DetailOffsetKey.self) { offset = $0 }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { collapsedBarBackground }
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            identity
            biography
            stats
            detailState
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(.largeTitle.bold())
                .overflowWrap()
                .accessibilityAddTraits(.isHeader)

            Text(viewModel.login)
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("detailLogin")
        }
    }

    @ViewBuilder
    private var biography: some View {
        if viewModel.isLoadingFields {
            Skeleton()
                .frame(height: 42)
        } else if let bio = viewModel.bio {
            Text(bio)
                .font(.body)
                .overflowWrap()
        }
    }

    private var stats: some View {
        ProfileStats(stats: viewModel.stats)
            .overlay {
                if viewModel.isLoadingFields {
                    Skeleton()
                }
            }
            .accessibilityHidden(viewModel.isLoadingFields)
    }

    @ViewBuilder
    private var detailState: some View {
        switch viewModel.state {
        case .idle, .loading:
            Skeleton()
                .frame(height: 170)

        case let .failed(error):
            ErrorState(error: error, retry: viewModel.retry)

        case .loaded:
            ProfileInfo(rows: viewModel.infoRows)
                .tint(.accentColor)
            if let error = viewModel.refreshError {
                ErrorState(error: error, retry: viewModel.retry)
                    .accessibilityIdentifier("detailRefreshError")
            }
        }
    }

    private var collapsedBarBackground: some View {
        Rectangle()
            .fill(reduceTransparency ? AnyShapeStyle(.background) : AnyShapeStyle(.regularMaterial))
            .frame(height: 100)
            .opacity(collapse)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }

    private var collapsedTitle: some View {
        Text(viewModel.title)
            .font(.headline)
            .opacity(collapse)
            .accessibilityHidden(collapse < 0.9)
    }

    private func closeAvatar() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            showingAvatar = false
        }
    }
}

#if DEBUG
    #Preview("GitHubUser Detail") {
        NavigationStack {
            UserDetailView(user: .preview, service: PreviewGitHubClient())
        }
        .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
