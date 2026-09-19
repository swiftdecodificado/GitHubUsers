import CoreGraphics
import GitHubAPI

struct UserListItemPresentation {
    let displayLines: [String]
    let accessibilityName: String

    init(user: GitHubUser) {
        displayLines = [user.login, user.name]
            .compactMap(\.self)
            .filter { !$0.isEmpty }
        accessibilityName = displayLines.joined(separator: ", ")
    }
}

enum UserCardMetrics {
    static func waterfallHeight(for seed: Int) -> CGFloat {
        CGFloat(150 + seed % 4 * 35)
    }
}
