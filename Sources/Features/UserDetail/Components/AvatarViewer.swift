import GitHubAPI
import SwiftUI

struct AvatarViewer: View {
    let url: URL
    let login: String
    let namespace: Namespace.ID
    let dismiss: () -> Void

    @State private var displacement: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .opacity(max(0.3, 1 - abs(displacement.height) / 500))
                    .ignoresSafeArea()

                RemoteImage(url: url, name: login)
                    .frame(
                        width: min(geometry.size.width, geometry.size.height),
                        height: min(geometry.size.width, geometry.size.height),
                    )
                    .matchedGeometryEffect(id: "viewerAvatar", in: namespace)
                    .scaleEffect(reduceMotion ? 1 : max(0.65, 1 - abs(displacement.height) / 1000))
                    .offset(displacement)
                    .onTapGesture(perform: dismiss)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(.default, dismiss)
                    .accessibilityIdentifier("fullScreenAvatar")
                    .gesture(DragGesture().onChanged { displacement = $0.translation }.onEnded { value in
                        let shouldDismiss = abs(value.translation.height) > 100
                            || abs(value.predictedEndTranslation.height) > 250

                        if shouldDismiss {
                            dismiss()
                        } else {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                                displacement = .zero
                            }
                        }
                    })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 48, height: 48)
                        .background(.black.opacity(0.7), in: Circle())
                }
                .foregroundStyle(.white)
                .padding(16)
                .accessibilityLabel(L10n.close)
                .accessibilityIdentifier("closeAvatar")
            }
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("avatarViewer")
    }
}

#if DEBUG
    private struct AvatarViewerPreview: View {
        @Namespace private var namespace

        var body: some View {
            AvatarViewer(
                url: GitHubUser.preview.avatarURL(size: 460),
                login: GitHubUser.preview.login,
                namespace: namespace,
                dismiss: {},
            )
            .environment(\.imageCache, GitHubImageCache(offline: true))
        }
    }

    #Preview("Avatar Viewer") {
        AvatarViewerPreview()
    }
#endif
