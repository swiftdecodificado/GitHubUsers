import Foundation
import GitHubAPI
@testable import GitHubUsers

private final class BundleToken {}
#if !SWIFT_PACKAGE
    extension Bundle { static var module: Bundle {
        Bundle(for: BundleToken.self)
    } }
#endif
enum Fixtures {
    enum FixtureError: Error {
        case missing(String)
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json")
            ?? Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        else {
            throw FixtureError.missing(name)
        }

        return try Data(contentsOf: url)
    }

    static func users() throws -> [GitHubUser] {
        try decoder.decode([GitHubUser].self, from: data("users_page1"))
    }

    static func detail() throws -> GitHubUserDetail {
        try decoder.decode(GitHubUserDetail.self, from: data("user_detail"))
    }
}
