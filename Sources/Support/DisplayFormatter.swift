import Foundation

enum DisplayFormatter {
    static func count(_ value: Int, locale: Locale = .current) -> String {
        guard value >= 1000 else {
            return value.formatted(.number.locale(locale))
        }

        let divisor = value >= 1_000_000 ? 1_000_000.0 : 1000.0
        let formatted = (Double(value) / divisor).formatted(
            .number
                .precision(.fractionLength(0 ... 1))
                .locale(locale)
        )

        return formatted + (divisor == 1000 ? "k" : "M")
    }
}
