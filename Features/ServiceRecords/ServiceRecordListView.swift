import SwiftUI
import SwiftData

// MARK: - Service Record List View
// Bakım kayıtları listesi. Tarihe göre sıralı, parça detayları.

struct ServiceRecordListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ServiceRecord.date, order: .reverse) private var allRecords: [ServiceRecord]
    @Query private var allParts: [PartChange]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var showAddRecord = false
    @State private var editingRecord: ServiceRecord?
    @State private var selectedVehicleFilter: UUID?
    @State private var operationError: String?

    private var filteredRecords: [ServiceRecord] {
        if let vid = selectedVehicleFilter {
            return allRecords.filter { $0.vehicleId == vid }
        }
        return allRecords
    }

    private func partsFor(_ record: ServiceRecord) -> [PartChange] {
        allParts.filter { $0.serviceRecordId == record.id }
    }

    var body: some View {
        Group {
            if allRecords.isEmpty {
                EmptyStateView(
                    icon: "wrench.and.screwdriver",
                    title: "Bakım geçmişini tut",
                    description: "Periyodik bakım, yağ değişimi ve onarım kayıtlarını ekleyerek aracının bakım geçmişini oluştur.",
                    actionTitle: "Bakım Ekle",
                    action: { showAddRecord = true }
                )
            } else {
                listContent
            }
        }
        .sheet(isPresented: $showAddRecord) {
            ServiceRecordFormView()
        }
        .sheet(item: $editingRecord) { record in
            ServiceRecordFormView(existingRecord: record)
        }
        .alert("İşlem Tamamlanamadı", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(operationError ?? "Bilinmeyen bir hata oluştu.")
        }
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

            Section {
                ForEach(filteredRecords) { record in
                    recordRow(record)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { deleteRecord(record) }
                            label: { Label("Sil", systemImage: "trash") }
                        }
                }
            } header: {
                Text("Bakım Kayıtları · \(filteredRecords.count)")
            }
            .listRowBackground(Color.appSurface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    private func recordRow(_ record: ServiceRecord) -> some View {
        Button {
            editingRecord = record
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.body)
                        .foregroundColor(AppColors.accentPrimary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.serviceType.displayName)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        if let vendor = record.vendorName, !vendor.isEmpty {
                            Text(vendor)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let cost = record.totalCostDisplay {
                            Text(cost)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        Text(record.dateDisplay)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                // Parçalar
                let parts = partsFor(record)
                if !parts.isEmpty {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "gearshape")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                        Text(parts.prefix(4).compactMap { p in
                            let name = [p.brand, p.partType.displayName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                            return name.isEmpty ? nil : name
                        }.joined(separator: " · "))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)

                        if parts.count > 4 {
                            Text("+\(parts.count - 4)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.accentPrimary)
                        }
                    }
                    .padding(.leading, 36)
                }

                // Km
                if let km = record.odometerDisplay {
                    HStack(spacing: 4) {
                        Spacer().frame(width: 24)
                        Image(systemName: "gauge.with.needle")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                        Text(km)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func deleteRecord(_ record: ServiceRecord) {
        for part in partsFor(record) {
            modelContext.delete(part)
        }
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            operationError = "Bakım kaydı silinemedi. Verileriniz değiştirilmedi."
        }
    }
}

#Preview("Bakım Listesi") {
    ServiceRecordListView()
        .modelContainer(MockDataProvider.previewContainer)
}
