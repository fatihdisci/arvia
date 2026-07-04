import SwiftUI

// MARK: - Sale File Readiness
enum SaleFileReadiness {
    case empty
    case partial(hasDocuments: Bool)
    case ready
}

// MARK: - Record Counts
struct RecordCounts {
    let bakim: Int
    let masraf: Int
    let belge: Int
    let ekspertiz: Int

    var total: Int { bakim + masraf + belge + ekspertiz }

    var summary: String {
        var parts: [String] = []
        if bakim > 0 { parts.append("\(bakim) bakım") }
        if masraf > 0 { parts.append("\(masraf) masraf") }
        if belge > 0 { parts.append("\(belge) belge") }
        if ekspertiz > 0 { parts.append("\(ekspertiz) ekspertiz") }
        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }
}

// MARK: - Sale File Preview Card
/// Satış Dosyası önizleme kartı. 3 durum: empty (kilitli), partial, ready.
/// Güvenli dil: Mekanik/hukuki garanti ima etmez.
struct SaleFilePreviewCard: View {
    let readiness: SaleFileReadiness
    let recordCounts: RecordCounts
    let onTap: () -> Void
    let onAddExpense: () -> Void

    var body: some View {
        switch readiness {
        case .empty:
            emptyStateCard
        case .partial:
            partialStateCard
        case .ready:
            readyStateCard
        }
    }

    // MARK: - Empty State (kilitli)
    private var emptyStateCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.textTertiary.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Satış Dosyası Hazır Değil")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                Text("En az 1 bakım veya masraf kaydı ekle.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            Button {
                onAddExpense()
            } label: {
                HStack(spacing: 4) {
                    Text("Ekle")
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .accessibilityLabel("Satış Dosyası henüz hazır değil — en az 1 kayıt ekle.")
    }

    // MARK: - Partial State (aktif ama eksik)
    private var partialStateCard: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.accentPrimary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.richtext")
                        .font(.title3)
                        .foregroundColor(AppColors.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Satış Dosyası")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    if !recordCounts.summary.isEmpty {
                        Text("\(recordCounts.summary) kaydından güven dosyası oluştur.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    if recordCounts.belge == 0 {
                        Text("Belge ekle, dosyanı güçlendir.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.warning)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(Color.appSurface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Satış Dosyası — \(recordCounts.summary) kaydından güven dosyası oluştur.")
        .accessibilityHint("Satış dosyası oluşturmak için çift tıkla")
    }

    // MARK: - Ready State (mevcut tasarım + count summary)
    private var readyStateCard: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.success.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.richtext")
                        .font(.title3)
                        .foregroundColor(AppColors.success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Satış Dosyası")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(recordCounts.summary) kaydından güven dosyası oluştur.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(Color.appSurface)
            )
            .subtleShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Satış Dosyası — \(recordCounts.summary) kaydından güven dosyası oluştur.")
        .accessibilityHint("Satış dosyası oluşturmak için çift tıkla")
    }
}
