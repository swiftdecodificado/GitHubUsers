import GitHubAPI
import SwiftUI

struct UserCard: View {
    let user: GitHubUser

    @ScaledMetric(relativeTo: .body) private var heightScale = 1.0
    private var presentation: UserListItemPresentation {
        UserListItemPresentation(user: user)
    }

    var body: some View {
        RemoteImage(url: user.avatarURL(size: 200), name: user.login)
            .frame(height: UserCardMetrics.waterfallHeight(for: user.id) * heightScale)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(presentation.displayLines.enumerated()), id: \.offset) { index, text in
                        Text(text)
                            .font(index == 0 ? .headline : .subheadline)
                            .overflowWrap()
                    }
                }
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    LinearGradient(
                        colors: [.black.opacity(0.82), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.user(presentation.accessibilityName))
    }
}

#if DEBUG
    #Preview("Grid Card") {
        UserCard(user: .preview)
            .frame(width: 180)
            .padding()
            .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
