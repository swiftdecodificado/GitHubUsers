import SwiftUI

struct Skeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 14)
                .fill(.quaternary)
                .overlay {
                    if !reduceMotion {
                        LinearGradient(
                            colors: [.clear, .primary.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing,
                        )
                        .offset(x: animating ? geometry.size.width : -geometry.size.width)
                        .animation(.linear(duration: 1.3).repeatForever(autoreverses: false), value: animating)
                    }
                }
                .clipped()
        }
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Skeleton") {
        VStack(spacing: 12) {
            Skeleton().frame(height: 200)
            Skeleton().frame(height: 42)
            Skeleton().frame(height: 42)
        }
        .padding()
    }
#endif
