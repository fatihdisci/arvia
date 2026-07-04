import SwiftUI

// MARK: - Upcoming Task Card
struct UpcomingTaskCard: View {
    let reminder: Reminder
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: reminder.type.defaultIcon).font(.title3).foregroundColor(statusColor).frame(width: 40, height: 40).background(Circle().fill(statusColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(AppTypography.captionMedium).foregroundColor(statusColor)
                Text(reminder.title).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary)
                if let dueDate = reminder.dueDate { Text(dueDate.formatted(date: .abbreviated, time: .omitted)).font(AppTypography.caption).foregroundColor(AppColors.textSecondary) }
            }
            Spacer()
            if reminder.isOverdue { Text("\(reminder.daysOverdue) gün").font(AppTypography.captionMedium).foregroundColor(AppColors.critical) }
            else if reminder.isToday { Text("Bugün").font(AppTypography.captionMedium).foregroundColor(AppColors.warning) }
            else { Text("\(reminder.daysRemaining) gün").font(AppTypography.captionMedium).foregroundColor(AppColors.textSecondary) }
        }
        .padding(AppSpacing.md).background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(statusColor.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine).accessibilityLabel("\(statusTitle): \(reminder.title)")
    }
    private var statusColor: Color { reminder.isOverdue ? AppColors.critical : (reminder.isToday ? AppColors.warning : AppColors.accentPrimary) }
    private var statusTitle: String { reminder.isOverdue ? "Gecikmiş İş" : (reminder.isToday ? "Bugün" : "Yaklaşan İş") }
}
