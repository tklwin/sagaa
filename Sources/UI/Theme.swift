import SwiftUI

public enum SagaaTheme {
    public static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    public static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    public static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.96)
    }

    public static let primaryAccent = Color(red: 0.15, green: 0.65, blue: 0.45) // Natural emerald jade
    public static let recordingRed = Color(red: 0.92, green: 0.26, blue: 0.28)
}

public struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SagaaTheme.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(SagaaTheme.cardBorder(for: colorScheme), lineWidth: 1)
                    )
            )
    }
}

public extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

