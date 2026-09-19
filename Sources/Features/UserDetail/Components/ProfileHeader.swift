import GitHubAPI
import SwiftUI

/// Blurred cover, the avatar button that opens the full screen viewer and the scroll offset the bar collapse reads.
struct ProfileHeader: View {
    let avatarURL: URL
    let login: String
    let offset: CGFloat
    let isAvatarOpen: Bool
    let namespace: Namespace.ID
    let openAvatar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            ProfileCover(url: avatarURL, login: login, offset: offset)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: DetailOffsetKey.self,
                            value: geometry.frame(in: .named("detailScroll")).minY
                        )
                    }
                }

            avatar
                .padding(.leading, 20)
                .padding(.top, 194)
        }
        .frame(height: 286)
    }

    private var avatar: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                openAvatar()
            }
        } label: {
            Group {
                if !isAvatarOpen {
                    RemoteImage(url: avatarURL, name: login)
                        .matchedGeometryEffect(id: "viewerAvatar", in: namespace)
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .overlay { Circle().stroke(.background, lineWidth: 4) }
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                } else {
                    Color.clear
                        .frame(width: 92, height: 92)
                }
            }
        }
        .buttonStyle(CardPressStyle())
        .accessibilityLabel(L10n.avatar(login))
        .accessibilityIdentifier("openAvatar")
    }
}

struct DetailOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat {
        0
    }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
    private struct ProfileHeaderPreview: View {
        @Namespace private var namespace

        var body: some View {
            ProfileHeader(
                avatarURL: GitHubUser.preview.avatarURL(size: 460),
                login: GitHubUser.preview.login,
                offset: 0,
                isAvatarOpen: false,
                namespace: namespace,
                openAvatar: {}
            )
        }
    }

    #Preview("Profile Header") {
        ProfileHeaderPreview()
            .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
