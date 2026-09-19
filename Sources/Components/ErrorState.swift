import GitHubAPI
import SwiftUI

struct ErrorState: View {
    let error: GitHubAPIError
    let retry: @MainActor () async -> Void

    @ViewBuilder
    var body: some View {
        Group {
            if error.resetAt != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(at: context.date)
                }
            } else {
                content(at: .now)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("errorState")
    }

    private func content(at date: Date) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.icloud")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(L10n.error)
                .font(.headline)

            Text(error.errorDescription ?? "")
                .multilineTextAlignment(.center)

            if error.resetAt != nil {
                Text(L10n.reset(error.remaining(at: date)))
                    .monospacedDigit()
            }

            Button(L10n.retry) {
                Task { await retry() }
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .disabled(!error.canRetry(at: date))
            .accessibilityIdentifier("retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#if DEBUG
    #Preview("Error State") {
        ErrorState(error: .network, retry: {})
            .padding()
    }
#endif
