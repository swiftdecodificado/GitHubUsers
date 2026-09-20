import GitHubAPI
import SwiftUI

struct ProfileCover: View {
    let url: URL
    let login: String
    let offset: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            let stretch = max(0, offset)
            let height = geometry.size.height + stretch
            let blurPadding: CGFloat = 56

            Rectangle()
                .fill(.clear)
                .frame(width: geometry.size.width, height: height)
                .background {
                    RemoteImage(url: url, name: login)
                        .frame(
                            width: geometry.size.width + blurPadding * 2,
                            height: height + blurPadding * 2
                        )
                        .blur(radius: 28, opaque: true)
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            .black.opacity(reduceTransparency ? 1 : 0.8),
                            .black.opacity(0.3),
                            .black.opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
                .offset(y: -stretch)
        }
        .frame(height: 240)
        .ignoresSafeArea(.container, edges: .horizontal)
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Profile Cover") {
        ProfileCover(
            url: GitHubUser.preview.avatarURL(size: 460),
            login: GitHubUser.preview.login,
            offset: 0
        )
        .frame(height: 240)
        .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
