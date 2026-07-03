import SwiftUI

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minimumTapTarget + 8)
            .padding(.horizontal, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(isEnabled ? AppColors.accentPrimary : AppColors.accentPrimary.opacity(0.4))
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(isEnabled ? AppColors.accentPrimary : AppColors.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minimumTapTarget + 8)
            .padding(.horizontal, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(isEnabled ? AppColors.accentPrimary.opacity(0.6) : AppColors.border, lineWidth: 1)
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.minimumTapTarget + 8)
            .padding(.horizontal, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColors.critical)
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.97 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Text Button Style (inline)
struct TextButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.accentPrimary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppColors.textSecondary)
            .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
            .background(
                Circle()
                    .fill(Color.appSurface)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - ButtonStyle extensions
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

extension ButtonStyle where Self == TextButtonStyle {
    static var text: TextButtonStyle { TextButtonStyle() }
}
