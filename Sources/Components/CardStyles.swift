import SwiftUI

struct CardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

struct CardEntrance: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(reduceMotion ? nil : cardAnimation) {
                    visible = true
                }
            }
    }

    private var cardAnimation: Animation {
        .easeOut(duration: 0.25)
            .delay(min(Double(index) * 0.025, 0.25))
    }
}

extension View {
    func overflowWrap() -> some View {
        fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
    #Preview("Card Press Style") {
        Button("Tap me") {}
            .buttonStyle(CardPressStyle())
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            .padding()
    }
#endif
