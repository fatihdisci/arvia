import SwiftUI

// MARK: - Inspection Report Card
// Kompakt: boş state tek satır CTA, dolu state 4-5 satır.
struct InspectionReportSection: View {
    let inspectionReports: [InspectionReport]
    let onAddInspection: () -> Void
    var onEditReport: ((InspectionReport) -> Void)?
    var onDeleteReport: ((InspectionReport) -> Void)?

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
                            .lineLimit(2)
                    }

                    // Aksiyon ipucu + hukuki uyarı
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                        Text(InspectionReport.legalDisclaimer)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)

                        Spacer(minLength: AppSpacing.sm)

                        Text("Düzenlemek için dokun")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.accentPrimary.opacity(0.7))
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .subtleShadow()
                .contentShape(Rectangle())
                .onTapGesture {
                    if let onEdit = onEditReport {
                        onEdit(latest)
                    }
                }
                .contextMenu {
                    if let onEdit = onEditReport {
                        Button {
                            onEdit(latest)
                        } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }
                    }
                    if let onDelete = onDeleteReport {
                        Button(role: .destructive) {
                            onDelete(latest)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    if let onDelete = onDeleteReport {
                        Button(role: .destructive) {
                            onDelete(latest)
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    if let onEdit = onEditReport {
                        Button {
                            onEdit(latest)
                        } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        .tint(AppColors.accentPrimary)
                    }
                }
            } else {
                // Kompakt tek satır CTA
                Button {
                    onAddInspection()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.accentPrimary)
                            .frame(width: 24)
                        Text("Ekspertiz raporu ekle")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.accentPrimary)
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .padding(AppSpacing.sm)
                    .frame(minHeight: 44)
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
