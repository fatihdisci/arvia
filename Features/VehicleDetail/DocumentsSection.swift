import SwiftUI
import QuickLook

// MARK: - Documents Section (Belgeler)
struct DocumentsSection: View {
    let documents: [VehicleDocument]
    @Binding var previewDocumentURL: URL?
    @Binding var showDocumentPreview: Bool
    let onAddDocument: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Belgeler",
                actionTitle: documents.isEmpty ? nil : "Ekle",
                action: {
                    onAddDocument()
                }
            )

            if documents.isEmpty {
                Button {
                    onAddDocument()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "doc.text")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Henüz belge yok")
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textPrimary)
                            Text("Belgelerini eklemek için tıkla.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.appSurface)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(documents.prefix(5)) { doc in
                        documentRow(doc)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.appSurface)
                )

                if documents.count > 5 {
                    Text("+\(documents.count - 5) belge daha")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, AppSpacing.xxs)
                }
            }
        }
    }

    private func documentRow(_ doc: VehicleDocument) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: doc.type.defaultIcon)
                .font(.body)
                .foregroundColor(AppColors.document)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.xxs) {
                    if doc.isExpired {
                        Text("Süresi Geçti")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.critical)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.critical.opacity(0.12))
                            )
                    } else if doc.isExpiringSoon {
                        Text("\(doc.daysUntilExpiry ?? 0) gün")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.warning.opacity(0.12))
                            )
                    }

                    if let size = doc.fileSizeDisplay {
                        Text(size)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Önizleme göstergesi — kullanıcıya tıklanabilir olduğunu belirtir
            Image(systemName: "eye")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
                .padding(.trailing, 2)

            if doc.includeInSaleFile {
                Image(systemName: "doc.richtext.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.accentPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppSpacing.minimumTapTarget)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .onTapGesture {
            previewDocument(doc)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteDocument(doc)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(doc.title.isEmpty ? doc.type.displayName : doc.title)
        .accessibilityHint(doc.isExpired ? "Süresi geçmiş belge" : "Görüntülemek için iki kere dokun")
    }

    private func previewDocument(_ doc: VehicleDocument) {
        let url = DocumentStorageService.shared.fileURL(for: doc.localFileName)
        previewDocumentURL = url
        showDocumentPreview = true
    }

    private func deleteDocument(_ doc: VehicleDocument) {
        try? DocumentStorageService.shared.deleteFile(doc.localFileName)
        modelContext.delete(doc)
        try? modelContext.save()
        Task { await NotificationRefreshService.refreshAll(context: modelContext) }
    }
}
