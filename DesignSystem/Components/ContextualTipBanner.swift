import SwiftUI

// MARK: - Contextual Tip Banner
// Bağlama göre inline info kartı. Kapatılabilir, UserDefaults ile takip edilir.
// Modal spam yapmaz. 1-2 cümle, premium, sakin tasarım.

struct ContextualTipBanner: View {
    let tipKey: String
    let icon: String
    let title: String
    let message: String

    @State private var isVisible: Bool = true
    @AppStorage("tip_dismissed") private var dismissedTipsData: String = ""

    private var dismissedKeys: Set<String> {
        Set(dismissedTipsData.split(separator: ",").map(String.init))
    }

    private var isDismissed: Bool { dismissedKeys.contains(tipKey) }

    var body: some View {
        if isVisible && !isDismissed {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(AppColors.accentPrimary.opacity(0.1))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: AppSpacing.minimumTapTarget, height: AppSpacing.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Kapat")
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.accentPrimary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.accentPrimary.opacity(0.12), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, AppSpacing.screenMarginH)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func dismiss() {
        var keys = dismissedKeys
        keys.insert(tipKey)
        dismissedTipsData = keys.sorted().joined(separator: ",")
        withAnimation(.easeOut(duration: 0.2)) { isVisible = false }
    }
}

// MARK: - Tip Constants
enum ContextualTips {
    static let todosFirstOpen = "tip_todos_first_open"
    static let historyFirstOpen = "tip_history_first_open"
    static let serviceCompleted = "tip_service_completed"
    static let documentFirstAdd = "tip_document_first_add"
    static let saleFileOpen = "tip_sale_file_open"

    static func hasSeen(_ key: String) -> Bool {
        let dismissed = UserDefaults.standard.string(forKey: "tip_dismissed") ?? ""
        return dismissed.split(separator: ",").map(String.init).contains(key)
    }
}

#Preview("Tip Banner") {
    VStack(spacing: AppSpacing.md) {
        ContextualTipBanner(
            tipKey: "test_tip",
            icon: "lightbulb",
            title: "Burayı biliyor musun?",
            message: "Burada yaklaşan işleri görürsün. Muayene, sigorta ve bakım tarihlerini ekleyebilirsin."
        )
    }
    .padding(.vertical)
    .background(Color.appBackground)
}
