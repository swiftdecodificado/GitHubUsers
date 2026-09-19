import SwiftUI

struct EmptyState: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#if DEBUG
    #Preview("Empty State") {
        EmptyState(title: "No users found", symbol: "person.2")
    }
#endif
