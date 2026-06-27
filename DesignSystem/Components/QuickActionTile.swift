import SwiftUI

// MARK: - Quick Action Tile
// Garaj ekranında ana araç altındaki hızlı işlem butonları.
// Kompakt, ikon + tek satır etiket, minimum 44pt tap target.

struct QuickActionTile: View {
    let icon: String
    let label: String
    let color: Color
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
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(color.opacity(0.1))
                    )

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppSpacing.minimumTapTarget)
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
        .accessibilityHint("\(label) eklemek için çift tıkla")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Quick Action Rail
// 5 eşit genişlikli buton, yatay sıralı. Kısa etiketlerle dar ekrana sığar.

struct QuickActionRail: View {
    let actions: [QuickAction]

    struct QuickAction: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let color: Color
        let action: () -> Void
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                QuickActionTile(
                    icon: action.icon,
                    label: action.label,
                    color: action.color,
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
