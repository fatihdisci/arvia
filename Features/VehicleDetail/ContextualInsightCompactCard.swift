import SwiftUI

// MARK: - Contextual Insight Compact Card
struct ContextualInsightCompactCard: View {
    let insight: VehicleInsight; var prominence: Prominence = .secondary; let action: () -> Void
    enum Prominence { case primary; case secondary }
    var body: some View {
        VStack(alignment: .leading, spacing: prominence == .primary ? AppSpacing.md : AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon).font(prominence == .primary ? .title3 : .body).foregroundColor(color).frame(width: prominence == .primary ? 42 : 32, height: prominence == .primary ? 42 : 32).background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(color.opacity(prominence == .primary ? 0.15 : 0.1))).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title).font(prominence == .primary ? AppTypography.cardTitle : AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                    Text(insight.body).font(prominence == .primary ? AppTypography.secondarySmall : AppTypography.caption).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button { action() } label: { HStack(spacing: AppSpacing.xs) { Text(insight.action?.title ?? "").font(AppTypography.captionMedium); Image(systemName: "arrow.right").font(.caption2.weight(.semibold)) }.foregroundColor(prominence == .primary ? AppColors.textOnAccent : AppColors.accentPrimary).padding(.horizontal, prominence == .primary ? AppSpacing.sm : 0).frame(minHeight: AppSpacing.minimumTapTarget, alignment: .leading).background(Capsule().fill(prominence == .primary ? color : Color.clear)) }.buttonStyle(.plain)
        }
        .padding(prominence == .primary ? AppSpacing.md : AppSpacing.sm).background(RoundedRectangle(cornerRadius: prominence == .primary ? AppRadius.heroCard : AppRadius.card).fill(backgroundFill))
        .overlay(RoundedRectangle(cornerRadius: prominence == .primary ? AppRadius.heroCard : AppRadius.card).stroke(color.opacity(prominence == .primary ? 0.2 : 0.12), lineWidth: 1))
        .subtleShadow().accessibilityElement(children: .combine).accessibilityLabel("\(insight.title). \(insight.body)")
    }
    private var backgroundFill: LinearGradient { LinearGradient(colors: prominence == .primary ? [Color.appSurface, color.opacity(0.095)] : [Color.appSurface, AppColors.backgroundSecondary.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing) }
    private var color: Color { switch insight.priority { case .important: AppColors.critical; case .warning: AppColors.warning; case .info: AppColors.accentPrimary } }
    private var icon: String { switch insight.type { case .overdueReminder: "exclamationmark.triangle.fill"; case .upcomingReminder: "bell.badge"; case .calendarPeriod: "calendar.badge.clock"; case .odometerUpdate: "gauge.with.needle"; case .seasonalGuidance: "sun.max"; case .missingDocument: "doc.text"; case .monthlyExpensePrompt: "turkishlirasign.circle"; case .fuelTypeGuidance: "fuelpump"; case .transmissionGuidance: "gearshape.2"; case .odometerMilestone: "flag.checkered"; case .maintenance: "wrench.and.screwdriver"; case .quietGoodState: "checkmark.seal"; case .saleFileReadiness: "doc.richtext" } }
}
