//
//  AppRootView.swift
//
//  Created by Luan Rodrigues on 12/09/26.
//

import GitHubAPI
import SwiftUI

struct AppRootView: View {
    private let cache: GitHubUserCache
    private let service: any GitHubClientProtocol

    @State private var path: [GitHubUser] = []
    @StateObject private var listViewModel: UsersListViewModel

    init(service: any GitHubClientProtocol) {
        let cache = GitHubUserCache()
        self.cache = cache
        self.service = service
        _listViewModel = StateObject(wrappedValue: UsersListViewModel(service: service, cache: cache))
    }

    var body: some View {
        NavigationStack(path: $path) {
            UsersListView(vm: listViewModel)
                .navigationDestination(for: GitHubUser.self) { user in
                    UserDetailView(user: user, service: service, cache: cache)
                }
        }
        .onReturnFromBackground {
            guard path.isEmpty else {
                return
            }

            await listViewModel.refreshAfterBackground()
        }
    }
}
