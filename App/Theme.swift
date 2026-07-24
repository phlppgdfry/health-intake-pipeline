import SwiftUI
import UIKit

/// The design system: one palette, one card treatment, one button language.
/// Colors are adaptive — a warm cream canvas with espresso ink in light mode,
/// the inverse warmth in dark mode — so the brand survives both appearances.
enum Theme {
    // Palette (warm health-brand hues)
    static let primary = Color(hex: 0xFF6900)        // vivid orange
    static let primaryDeep = Color(hex: 0xBE5710)    // pressed / gradients
    static let amber = Color(hex: 0xFFB81C)
    static let blush = Color(hex: 0xFF8DA1)

    static let canvas = Color(light: 0xF5F1EA, dark: 0x1F1415)
    static let card = Color(light: 0xFFFFFF, dark: 0x2C1D1F)
    static let ink = Color(light: 0x3F2021, dark: 0xF5F1EA)
    static let inkSoft = Color(light: 0x8A6E6F, dark: 0xC9B4B5)

    static let heroGradient = LinearGradient(
        colors: [primary, amber],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Components

/// Filled brand button for the one primary action per screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                isEnabled ? (configuration.isPressed ? Theme.primaryDeep : Theme.primary) : Theme.inkSoft,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: isEnabled ? Theme.primary.opacity(0.35) : .clear, radius: 10, y: 4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet sibling of the primary button, for secondary actions like "Retake".
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 15)
            .padding(.horizontal, 22)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.12)))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Card surface used for every grouped block of content.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }

    /// Standard screen chrome: warm canvas behind everything, brand tint.
    func themedScreen() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas.ignoresSafeArea())
            .tint(Theme.primary)
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Adaptive color from two hex values, resolved by the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}
