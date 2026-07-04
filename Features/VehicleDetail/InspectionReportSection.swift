import SwiftUI

// MARK: - Inspection Report Card
struct InspectionReportSection: View {
    let inspectionReports: [InspectionReport]
    let onAddInspection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let latest = inspectionReports.first {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundColor(AppColors.accentPrimary)
                        Text("Ekspertiz Raporu")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        // TODO: Partner doğrulama entegrasyonu geldiğinde badge eklenecek
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(latest.providerName)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textPrimary)
                        if let branch = latest.branchName, !branch.isEmpty {
                            Text(branch)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Text("\(latest.dateDisplay)\(latest.odometerDisplay.map { " · \($0)" } ?? "")")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    if !latest.summary.isEmpty {
                        Text(latest.summary)
                            .font(AppTypography.secondarySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(3)
                    }

                    // Hukuki uyarı
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                        Text(InspectionReport.legalDisclaimer)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(2)
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .subtleShadow()
            } else {
                // Ekspertiz yok — ekleme çağrısı
                Button {
                    onAddInspection()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ekspertiz raporu ekle")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("Aracının ekspertiz raporunu ekleyerek satış dosyanı güçlendir.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(Color.appSurface)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
