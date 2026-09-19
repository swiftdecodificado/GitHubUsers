import GitHubAPI
import SwiftUI

struct ProfileCover: View {
    let url: URL
    let login: String
    let offset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            RemoteImage(url: url, name: login)
                .frame(width: geometry.size.width, height: 240 + max(0, offset))
                .blur(radius: 28)
                .scaleEffect(reduceMotion ? 1 : 1 + max(0, offset) / 700)
                .overlay {
                    LinearGradient(
                        colors: [
                            .black.opacity(reduceTransparency ? 1 : 0.8),
                            .black.opacity(0.3),
                            .black.opacity(0.65),
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    )
                }
                .drawingGroup()
                .offset(y: reduceMotion ? 0 : (offset > 0 ? -offset : -offset * 0.28))
        }
        .frame(height: 240)
        .clipped()
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Profile Cover") {
        ProfileCover(
            url: GitHubUser.preview.avatarURL(size: 460),
            login: GitHubUser.preview.login,
            offset: 0,
        )
        .frame(height: 240)
        .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
