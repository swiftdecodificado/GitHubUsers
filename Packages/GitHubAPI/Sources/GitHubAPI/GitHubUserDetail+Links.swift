import Foundation

public extension GitHubUserDetail {
    var blogURL: URL? {
        guard let value = blog?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              let url = URL(
                  string: value.contains("://") ? value : "https://" + value,
              ),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil
        else {
            return nil
        }

        return url
    }
}
