import SwiftUI

// MARK: - Floating Quick Action Button (FAB)
// Garaj ekranında sağ alt köşede konumlanan dairesel buton.
// Basınca spring animasyonla 3 hızlı işlem butonu yukarı doğru açılır.
// Fiş/Fatura Tara free kullanıcıda Pro rozeti gösterir.

struct FloatingQuickActionButton: View {
    let onAddExpense: () -> Void
    let onScanReceipt: () -> Void
    let onAddReminder: () -> Void
    let showReceiptProBadge: Bool

    @State private var isExpanded = false

    // MARK: - Animation
    private let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    var body: some View {
        ZStack {
            // Dim overlay — expanded state only
            if isExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss() }
                    .accessibilityLabel("Kapat")
            }

            // Action buttons + FAB
            VStack(spacing: 12) {
                Spacer()

                // Expanded action buttons
                if isExpanded {
                    fabAction(
                        icon: "turkishlirasign.circle",
                        label: "Masraf Ekle",
                        color: AppColors.accentPrimary
                    ) {
                        dismiss()
                        onAddExpense()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    fabAction(
                        icon: "doc.viewfinder",
                        label: "Fiş/Fatura Tara",
                        color: AppColors.accentPrimary,
                        showProBadge: showReceiptProBadge
                    ) {
                        dismiss()
                        onScanReceipt()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    fabAction(
                        icon: "bell.badge",
                        label: "Hatırlatıcı Ekle",
                        color: AppColors.success
                    ) {
                        dismiss()
                        onAddReminder()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Main FAB
                Button {
                    if isExpanded {
                        dismiss()
                    } else {
                        withAnimation(spring) {
                            isExpanded = true
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(AppColors.accentPrimary))
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                }
                .accessibilityLabel(isExpanded ? "Kapat" : "Hızlı İşlemler")
            }
            .padding(.trailing, AppSpacing.md)
            .padding(.bottom, AppSpacing.floatingTabBarContentInset + AppSpacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .animation(spring, value: isExpanded)
    }

    private func dismiss() {
        withAnimation(spring) { isExpanded = false }
    }

    // MARK: - Action Pill Button
    private func fabAction(
        icon: String,
        label: String,
        color: Color,
        showProBadge: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(AppTypography.secondaryMedium)
                    .foregroundColor(AppColors.textPrimary)
                if showProBadge {
                    Text("Pro")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.accentPrimary))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.appSurface)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            )
        }
        .accessibilityLabel(showProBadge ? "\(label), Pro" : label)
    }
}

// MARK: - Preview
#Preview("FAB — Kapalı") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        FloatingQuickActionButton(
            onAddExpense: {},
            onScanReceipt: {},
            onAddReminder: {},
            showReceiptProBadge: true
        )
    }
}

#Preview("FAB — Açık") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        FloatingQuickActionButton(
            onAddExpense: {},
            onScanReceipt: {},
            onAddReminder: {},
            showReceiptProBadge: true
        )
    }
}
