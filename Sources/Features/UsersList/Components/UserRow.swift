import GitHubAPI
import SwiftUI

struct UserRow: View {
    let user: GitHubUser

    private var presentation: UserListItemPresentation {
        UserListItemPresentation(user: user)
    }

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(url: user.avatarURL(size: 200), name: user.login)
                .frame(width: 52, height: 52)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(presentation.displayLines.enumerated()), id: \.offset) { index, text in
                    Text(text)
                        .font(index == 0 ? .headline : .subheadline)
                        .foregroundStyle(index == 0 ? .primary : .secondary)
                        .overflowWrap()
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 66)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.user(presentation.accessibilityName))
    }
}

#if DEBUG
    #Preview("User Row") {
        UserRow(user: .preview)
            .padding(.horizontal)
            .environment(\.imageCache, GitHubImageCache(offline: true))
    }
#endif
