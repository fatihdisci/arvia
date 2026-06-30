import SwiftUI

// MARK: - Arvia Guide Card
// Calm, local guidance card for the rule-based Rehber foundation.

struct ArviaGuideCard: View {
    let insight: VehicleInsight
    let primaryAction: () -> Void
    let dismissAction: (() -> Void)?

    init(
        insight: VehicleInsight,
        primaryAction: @escaping () -> Void,
        dismissAction: (() -> Void)? = nil
    ) {
        self.insight = insight
        self.primaryAction = primaryAction
        self.dismissAction = dismissAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(priorityColor)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(priorityColor.opacity(0.1))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.body)
                        .font(AppTypography.secondarySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.xs)
            }

            HStack(spacing: AppSpacing.xs) {
                Button(action: primaryAction) {
                    Label(insight.action.title, systemImage: actionIconName)
                        .font(AppTypography.captionMedium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.accentPrimary)
                .frame(minHeight: AppSpacing.minimumTapTarget, alignment: .leading)

                Spacer()

                if let dismissAction {
                    Button(action: dismissAction) {
                        Text("Daha sonra")
                            .font(AppTypography.captionMedium)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(minHeight: AppSpacing.minimumTapTarget)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appSurface,
                            priorityColor.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(priorityColor.opacity(insight.priority == .info ? 0.1 : 0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body). \(insight.action.title)")
    }

    private var iconName: String {
        switch insight.type {
        case .maintenance:
            return "wrench.and.screwdriver"
        case .missingDocument:
            return "doc.text"
        case .saleFileReadiness:
            return "doc.richtext"
        case .odometerUpdate:
            return "gauge.with.needle"
        case .overdueReminder:
            return "bell.badge"
        case .monthlyExpensePrompt:
            return "turkishlirasign.circle"
        case .upcomingReminder:
            return "calendar.badge.clock"
        case .fuelTypeGuidance:
            return "fuelpump"
        case .transmissionGuidance:
            return "gearshape.2"
        case .odometerMilestone:
            return "flag.checkered"
        case .seasonalGuidance:
            return "sun.max"
        case .calendarPeriod:
            return "calendar"
        case .quietGoodState:
            return "checkmark.seal"
        }
    }

    private var actionIconName: String {
        switch insight.action {
        case .addServiceRecord:
            return "plus.circle"
        case .addDocument:
            return "doc.badge.plus"
        case .openSaleFile:
            return "doc.richtext"
        case .updateOdometer:
            return "gauge.with.needle"
        case .openTodos:
            return "checklist"
        case .addInspectionReport:
            return "magnifyingglass"
        case .addReminder, .addMTVReminder:
            return "bell.badge"
        case .addExpense:
            return "turkishlirasign.circle"
        case .addFuelExpense:
            return "fuelpump"
        }
    }

    private var priorityColor: Color {
        switch insight.priority {
        case .info:
            return AppColors.accentPrimary
        case .warning:
            return AppColors.warning
        case .important:
            return AppColors.critical
        }
    }
}
