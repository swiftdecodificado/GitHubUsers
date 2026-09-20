import Foundation
import GitHubAPI

extension GitHubAPIError {
    var errorDescription: String? {
        switch self {
        case .transport:
            String(localized: "error.network", defaultValue: "Não foi possível conectar. Verifique sua conexão.")
        case .notFound:
            String(localized: "error.notFound", defaultValue: "Usuário não encontrado.")
        case .invalidInput, .invalidBaseURL, .invalidResponse, .unauthorized, .forbidden, .http:
            String(localized: "error.server", defaultValue: "O GitHub está indisponível. Tente novamente.")
        case .decoding:
            String(localized: "error.decoding", defaultValue: "Não foi possível ler a resposta do GitHub.")
        case .rateLimited:
            String(localized: "error.rateLimited", defaultValue: "Limite de requisições atingido.")
        case .unknown:
            String(localized: "error.unknown", defaultValue: "Não foi possível concluir a operação. Tente novamente.")
        }
    }
}
