import SwiftUI

// MARK: - Current Status
struct CurrentStatusSection: View {
    let expenses: [Expense]
    let upcomingTasks: [VehicleUpcomingTask]
    let onAddExpense: () -> Void

    @EnvironmentObject private var navigationRouter: AppNavigationRouter

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Güncel Durum")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: AppSpacing.sm) {
                monthlySummaryCard
                nextTasksCard
            }
        }
    }

    // MARK: - Monthly Summary
    private var monthlySummaryCard: some View {
        let summary = VehicleInsightService.shared.monthlySummary(expenses: expenses)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Bu Ay")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Masraf Ekle") {
                    onAddExpense()
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
                .frame(minHeight: AppSpacing.minimumTapTarget)
            }

            if summary.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "turkishlirasign.circle")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary.opacity(0.6))
                        Text("Bu ay henüz masraf kaydı yok.")
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(VehicleInsightService.shared.formattedTRY(summary.total))
                            .font(AppTypography.amount)
                            .foregroundColor(AppColors.textPrimary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.accentPrimary.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text("\(summary.count) masraf kaydı")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    if let topCategory = summary.topCategory {
                        Label(topCategory.displayName, systemImage: topCategory.defaultIcon)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.accentPrimary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .fill(AppColors.accentPrimary.opacity(0.08))
                            )
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Next Tasks
    private var nextTasksCard: some View {
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Sıradaki İşler")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Tümünü Gör") {
                    navigationRouter.selectedTab = .todos
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
                .frame(minHeight: AppSpacing.minimumTapTarget)
            }

            if upcomingTasks.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(AppColors.success.opacity(0.7))
                    Text("Yaklaşan bir iş görünmüyor.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .frame(minHeight: AppSpacing.minimumTapTarget)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingTasks.prefix(4).enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: AppSpacing.sm) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(priorityColor(task.priority))
                                .frame(width: 4, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(AppTypography.secondaryMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    if task.priority == .important {
                                        Text("Gecikti")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(AppColors.critical)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(
                                                Capsule()
                                                    .fill(AppColors.critical.opacity(0.1))
                                            )
                                    } else {
                                        Text(task.relativeText)
                                            .font(AppTypography.caption)
                                            .foregroundColor(priorityColor(task.priority))
                                    }
                                }
                            }

                            Spacer()
                        }
                        .frame(minHeight: AppSpacing.minimumTapTarget)

                        if index < min(upcomingTasks.count, 4) - 1 {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func priorityColor(_ priority: VehicleInsightPriority) -> Color {
        switch priority {
        case .important:
            return AppColors.critical
        case .warning:
            return AppColors.warning
        case .info:
            return AppColors.accentPrimary
        }
    }
}
