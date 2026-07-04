import SwiftUI

// MARK: - Recent Records Section
struct RecentRecordsSection: View {
    let expenses: [Expense]
    let serviceRecords: [ServiceRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Son Kayıtlar",
                actionTitle: expenses.isEmpty && serviceRecords.isEmpty ? nil : "Tümü",
                action: {}
            )

            if expenses.isEmpty && serviceRecords.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                    Text("Henüz kayıt yok. Masraf veya bakım ekleyerek başlayabilirsin.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.appSurface)
                )
                .padding(.horizontal, AppSpacing.screenMarginH)
            } else {
                let recentItems = recentRecords()
                VStack(spacing: AppSpacing.xs) {
                    ForEach(recentItems.prefix(3)) { item in
                        recentRecordRow(item)
                    }
                }
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
        }
    }

    private func recentRecords() -> [RecentRecordItem] {
        var items: [RecentRecordItem] = []

        for expense in expenses {
            items.append(RecentRecordItem(
                id: expense.id,
                type: .expense,
                title: expense.category.displayName,
                subtitle: expense.amountCompactDisplay,
                date: expense.date,
                icon: expense.category.defaultIcon
            ))
        }

        for service in serviceRecords {
            items.append(RecentRecordItem(
                id: service.id,
                type: .service,
                title: service.serviceType.displayName,
                subtitle: service.vendorName ?? service.totalCostDisplay ?? "",
                date: service.date,
                icon: "wrench.and.screwdriver"
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private func recentRecordRow(_ item: RecentRecordItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: item.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(AppColors.accentPrimary.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(item.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.date.formatted(date: .numeric, time: .omitted))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .monospacedDigit()
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColors.backgroundSecondary.opacity(0.42))
        )
    }
}
