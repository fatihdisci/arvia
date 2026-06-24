import SwiftUI
import SwiftData
import QuickLook

// MARK: - Document List View
// Türe göre gruplandırılmış belge listesi. Önizleme, expiry durumu, silme.

struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VehicleDocument.createdAt, order: .reverse) private var allDocuments: [VehicleDocument]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var showAddDocument = false
    @State private var editingDocument: VehicleDocument?
    @State private var selectedVehicleFilter: UUID?
    @State private var previewURL: URL?
    @State private var showPreview = false

    private var filteredDocuments: [VehicleDocument] {
        if let vid = selectedVehicleFilter {
            return allDocuments.filter { $0.vehicleId == vid }
        }
        return allDocuments
    }

    private var groupedDocuments: [(DocumentType, [VehicleDocument])] {
        var groups: [DocumentType: [VehicleDocument]] = [:]
        for doc in filteredDocuments {
            groups[doc.type, default: []].append(doc)
        }
        return groups.sorted { $0.key.displayName < $1.key.displayName }
    }

    var body: some View {
        Group {
            if allDocuments.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: "Belgelerini burada saklayabilirsin",
                    description: "Poliçe, muayene, ekspertiz ve faturaları aracının dijital dosyasına ekle.",
                    actionTitle: "Belge Ekle",
                    action: { showAddDocument = true }
                )
            } else {
                listContent
            }
        }
        .sheet(isPresented: $showAddDocument) { DocumentFormView() }
        .sheet(item: $editingDocument) { doc in DocumentFormView(existingDocument: doc) }
        .quickLookPreview($previewURL)
    }

    private var listContent: some View {
        List {
            if vehicles.count > 1 {
                Section {
                    Picker("Araç", selection: $selectedVehicleFilter) {
                        Text("Tüm Araçlar").tag(nil as UUID?)
                        ForEach(vehicles) { v in
                            Text(v.plate.isEmpty ? v.fullName : "\(v.plate) — \(v.fullName)").tag(v.id as UUID?)
                        }
                    }
                }
                .listRowBackground(Color.appSurface)
            }

            ForEach(groupedDocuments, id: \.0) { type, docs in
                Section {
                    ForEach(docs) { doc in
                        documentRow(doc)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleteDocument(doc) }
                                label: { Label("Sil", systemImage: "trash") }
                            }
                    }
                } header: {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: type.defaultIcon)
                            .font(.caption)
                        Text(type.displayName)
                        Text("· \(docs.count)")
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textPrimary)
                }
                .listRowBackground(Color.appSurface)
            }

            // Depolama bilgisi
            Section {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(AppColors.textTertiary)
                    Text("Toplam depolama")
                        .font(AppTypography.secondary)
                    Spacer()
                    Text(DocumentStorageService.shared.totalStorageDisplay)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .listRowBackground(Color.appSurface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func documentRow(_ doc: VehicleDocument) -> some View {
        Button {
            editingDocument = doc
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Belge tipi ikonu
                Image(systemName: doc.type.defaultIcon)
                    .font(.body)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xxs) {
                        if let vehicle = vehicles.first(where: { $0.id == doc.vehicleId }) {
                            Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        if let size = doc.fileSizeDisplay {
                            Text("· \(size)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }

                Spacer()

                // Expiry badge
                if doc.isExpired {
                    Text("Süresi Geçti")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.critical)
                        .padding(.horizontal, AppSpacing.xxs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.criticalBackground))
                } else if doc.isExpiringSoon {
                    Text("\(doc.daysUntilExpiry ?? 0) gün")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, AppSpacing.xxs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.warningBackground))
                }

                // Satış dosyası rozeti
                if doc.includeInSaleFile {
                    Image(systemName: "doc.richtext.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                previewDocument(doc)
            } label: {
                Label("Önizle", systemImage: "eye")
            }
            .tint(AppColors.accentPrimary)
        }
    }

    // MARK: - Preview
    private func previewDocument(_ doc: VehicleDocument) {
        let url = DocumentStorageService.shared.fileURL(for: doc.localFileName)
        guard DocumentStorageService.shared.fileExists(doc.localFileName) else { return }
        previewURL = url
        showPreview = true
    }

    // MARK: - Delete
    private func deleteDocument(_ doc: VehicleDocument) {
        try? DocumentStorageService.shared.deleteFile(doc.localFileName)
        modelContext.delete(doc)
        try? modelContext.save()
    }
}

#Preview("Belge Listesi") {
    DocumentListView()
        .modelContainer(MockDataProvider.previewContainer)
}
