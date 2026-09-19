import SwiftUI

private struct ReturnFromBackgroundModifier: ViewModifier {
    let action: @MainActor () async -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var wasBackgrounded = false

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    wasBackgrounded = true
                }

                if newPhase == .active, wasBackgrounded {
                    wasBackgrounded = false
                    Task {
                        await action()
                    }
                }
            }
    }
}

extension View {
    func onReturnFromBackground(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(ReturnFromBackgroundModifier(action: action))
    }
}
