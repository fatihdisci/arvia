import SwiftUI

// MARK: - Quick Action Tile
// Garaj ekranında ana araç altındaki hızlı işlem butonları.
// Kompakt, ikon + tek satır etiket, minimum 44pt tap target.

struct QuickActionTile: View {
    let icon: String
    let label: String
    let color: Color
    var style: QuickActionRail.Style = .dashboard
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: {
            if !reduceMotion {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
            action()
        }) {
            VStack(spacing: style.labelSpacing) {
                Image(systemName: icon)
                    .font(.system(size: style.iconFontSize, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: style.iconSize, height: style.iconSize)
                    .background(
                        Circle()
                            .fill(color.opacity(style.iconBackgroundOpacity))
                    )

                Text(label)
                    .font(.system(size: style.labelFontSize, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: style.minimumHeight)
            .padding(.vertical, style.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(style.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(color.opacity(style.borderOpacity), lineWidth: 1)
            )
        }
        .buttonStyle(PlainCardButtonStyle())
        .accessibilityLabel(label)
        .accessibilityHint("\(label) eklemek için çift tıkla")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Quick Action Rail
// 5 eşit genişlikli buton, yatay sıralı. Kısa etiketlerle dar ekrana sığar.

struct QuickActionRail: View {
    let actions: [QuickAction]
    var style: Style = .dashboard

    struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let color: Color
        let action: () -> Void
    }

    enum Style {
        case dashboard
        case compact

        var minimumHeight: CGFloat {
            switch self {
            case .dashboard: return 72
            case .compact: return AppSpacing.minimumTapTarget
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .dashboard: return 36
            case .compact: return 30
            }
        }

        var iconFontSize: CGFloat {
            switch self {
            case .dashboard: return 18
            case .compact: return 15
            }
        }

        var labelFontSize: CGFloat {
            switch self {
            case .dashboard: return 11
            case .compact: return 10
            }
        }

        var labelSpacing: CGFloat {
            switch self {
            case .dashboard: return AppSpacing.xs
            case .compact: return AppSpacing.xxs
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .dashboard: return AppSpacing.xs
            case .compact: return 6
            }
        }

        var iconBackgroundOpacity: Double {
            switch self {
            case .dashboard: return 0.11
            case .compact: return 0.08
            }
        }

        var borderOpacity: Double {
            switch self {
            case .dashboard: return 0.08
            case .compact: return 0.055
            }
        }

        var backgroundColor: Color {
            switch self {
            case .dashboard: return Color.appSurface
            case .compact: return AppColors.backgroundSecondary.opacity(0.55)
            }
        }
    }

    var body: some View {
        HStack(spacing: style == .compact ? 6 : AppSpacing.xs) {
            ForEach(actions) { action in
                QuickActionTile(
                    icon: action.icon,
                    label: action.label,
                    color: action.color,
                    style: style,
                    action: action.action
                )
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }
}

// MARK: - Preview

#Preview("Quick Action Rail") {
    QuickActionRail(actions: [
        .init(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {},
        .init(icon: "wrench.and.screwdriver", label: "Bakım", color: AppColors.warning) {},
        .init(icon: "doc.text.viewfinder", label: "Belge", color: AppColors.document) {},
        .init(icon: "bell", label: "Hatırlatıcı", color: AppColors.vehicle) {},
        .init(icon: "doc.richtext", label: "Satış", color: AppColors.success) {},
    ])
    .padding()
    .background(Color.appBackground)
}
