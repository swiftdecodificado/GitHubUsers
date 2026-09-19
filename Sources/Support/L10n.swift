import Foundation

enum L10n {
    static var users: String {
        String(localized: "users", defaultValue: "Usuários")
    }

    static var search: String {
        String(localized: "search", defaultValue: "Buscar usuários")
    }

    static var grid: String {
        String(localized: "grid", defaultValue: "Mostrar grade")
    }

    static var list: String {
        String(localized: "list", defaultValue: "Mostrar lista")
    }

    static var emptyUsers: String {
        String(localized: "emptyUsers", defaultValue: "Nenhum usuário")
    }

    static var emptySearch: String {
        String(localized: "emptySearch", defaultValue: "Nenhum resultado")
    }

    static var retry: String {
        String(localized: "retry", defaultValue: "Tentar novamente")
    }

    static var refresh: String {
        String(localized: "refresh", defaultValue: "Atualizar")
    }

    static var error: String {
        String(localized: "error", defaultValue: "Não foi possível carregar")
    }

    static var repositories: String {
        String(localized: "repositories", defaultValue: "Repositórios")
    }

    static var info: String {
        String(localized: "info", defaultValue: "Informações")
    }

    static var close: String {
        String(localized: "close", defaultValue: "Fechar")
    }

    static var refreshed: String {
        String(
            localized: "refreshed",
            defaultValue: "Lista de usuários atualizada"
        )
    }

    static var loading: String {
        String(localized: "loading", defaultValue: "Carregando")
    }

    static func user(_ name: String) -> String {
        String(
            format: String(localized: "userLabel", defaultValue: "Usuário %@"),
            name
        )
    }

    static func avatar(_ name: String) -> String {
        String(
            format: String(
                localized: "avatarLabel",
                defaultValue: "Foto de %@"
            ),
            name
        )
    }

    static func reset(_ remaining: String) -> String {
        String(
            format: String(
                localized: "resetLabel",
                defaultValue: "Tente novamente em %@"
            ),
            remaining
        )
    }

    static func stat(_ kind: UserStat.Kind) -> String {
        switch kind {
        case .repositories:
            repositories
        case .followers:
            String(localized: "followers", defaultValue: "Seguidores")
        case .following:
            String(localized: "following", defaultValue: "Seguindo")
        }
    }

    static func info(_ kind: InfoRow.Kind) -> String {
        switch kind {
        case .company:
            String(localized: "company", defaultValue: "Empresa")
        case .location:
            String(localized: "location", defaultValue: "Localização")
        case .blog:
            String(localized: "blog", defaultValue: "Site")
        case .twitter:
            String(localized: "twitter", defaultValue: "Twitter")
        case .memberSince:
            String(localized: "memberSince", defaultValue: "Membro desde")
        }
    }
}
