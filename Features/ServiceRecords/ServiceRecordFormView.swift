import SwiftUI
import SwiftData

// MARK: - Service Record Form View
// Bakım kaydı ekleme/düzenleme. Parça değişim editörü ve sonraki hatırlatıcı seçeneği.

struct ServiceRecordFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    let existingRecord: ServiceRecord?

    // Ana alanlar
    @State private var serviceType: ServiceType = .periodic
    @State private var date = Date()
    @State private var odometerText = ""
    @State private var vendorName = ""
    @State private var laborCostText = ""
    @State private var partsCostText = ""
    @State private var totalCostText = ""
    @State private var oilType = ""
    @State private var notes = ""
    @State private var selectedVehicleId: UUID?

    // Parça listesi
    @State private var changedParts: [PartDraft] = []

    // Sonraki hatırlatıcı
    @State private var createNextReminder = false
    @State private var nextReminderType: ReminderType = .periodicService
    @State private var nextReminderDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var nextReminderOdometerText = ""

    @State private var validationErrors: [String] = []

    struct PartDraft: Identifiable {
        let id = UUID()
        var partType: PartType = .oil
        var brand = ""
        var model = ""
        var warrantyDate: Date?
        var hasWarranty = false
    }

    init(existingRecord: ServiceRecord? = nil, preselectedVehicleId: UUID? = nil) {
        self.existingRecord = existingRecord
        if let r = existingRecord {
            _serviceType = State(initialValue: r.serviceType)
            _date = State(initialValue: r.date)
            _odometerText = State(initialValue: r.odometer.map(String.init) ?? "")
            _vendorName = State(initialValue: r.vendorName ?? "")
            _laborCostText = State(initialValue: r.laborCost.map { String(Int($0)) } ?? "")
            _partsCostText = State(initialValue: r.partsCost.map { String(Int($0)) } ?? "")
            _totalCostText = State(initialValue: r.totalCost.map { String(Int($0)) } ?? "")
            _oilType = State(initialValue: r.oilType ?? "")
            _notes = State(initialValue: r.notes)
            _selectedVehicleId = State(initialValue: r.vehicleId)
        } else if let vid = preselectedVehicleId {
            _selectedVehicleId = State(initialValue: vid)
        }
    }

    private var isEditing: Bool { existingRecord != nil }
    private var odometer: Int? { Int(odometerText.trimmingCharacters(in: .whitespaces)) }
    private var laborCost: Double? { parseCost(laborCostText) }
    private var partsCost: Double? { parseCost(partsCostText) }
    private var totalCost: Double? { parseCost(totalCostText) }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailSection
                costSection
                partsSection
                nextReminderSection
                vehicleSection
                if !validationErrors.isEmpty { errorSection }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Bakım Düzenle" : "Bakım Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Kaydet" : "Ekle", action: saveRecord)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .onAppear {
                if !isEditing, vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
                // Düzenleme modunda mevcut parçaları yükle
                if isEditing, let record = existingRecord, changedParts.isEmpty {
                    loadExistingParts(for: record)
                }
            }
        }
    }

    // MARK: - Type
    private var typeSection: some View {
        Section {
            Picker("Bakım Türü", selection: $serviceType) {
                ForEach(ServiceType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .font(AppTypography.body)
            .pickerStyle(.menu)
        } header: {
            Text("Bakım Türü")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Detail
    private var detailSection: some View {
        Section {
            DatePicker("Tarih", selection: $date, displayedComponents: .date)
                .font(AppTypography.body)
            labeledField("Km", icon: "gauge.with.needle", text: $odometerText, keyboard: .numberPad)
            labeledField("Servis / Usta", icon: "building.2", text: $vendorName)
            if serviceType == .oil || serviceType == .periodic {
                labeledField("Kullanılan Yağ", icon: "drop", text: $oilType)
            }
            labeledField("Not", icon: "pencil.line", text: $notes)
        } header: {
            Text("Detaylar")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Costs
    private var costSection: some View {
        Section {
            labeledField("İşçilik (₺)", icon: "wrench", text: $laborCostText, keyboard: .decimalPad)
            labeledField("Parça (₺)", icon: "gearshape", text: $partsCostText, keyboard: .decimalPad)
            labeledField("Toplam (₺)", icon: "banknote", text: $totalCostText, keyboard: .decimalPad)
        } header: {
            Text("Maliyet")
        } footer: {
            Text("Toplamı manuel girebilir veya işçilik + parça olarak bırakabilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Changed Parts
    private var partsSection: some View {
        Section {
            ForEach($changedParts) { $part in
                partEditor($part)
            }

            Button {
                changedParts.append(PartDraft())
            } label: {
                Label("Parça Ekle", systemImage: "plus.circle")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.accentPrimary)
            }

            if !changedParts.isEmpty {
                Button(role: .destructive) {
                    changedParts.removeAll()
                } label: {
                    Label("Tüm Parçaları Temizle", systemImage: "trash")
                        .font(AppTypography.caption)
                }
            }
        } header: {
            Text("Değişen Parçalar")
        } footer: {
            if changedParts.isEmpty {
                Text("Yağ, filtre, balata gibi değişen parçaları ekleyebilirsin.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    private func partEditor(_ part: Binding<PartDraft>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Picker("Parça", selection: part.partType) {
                ForEach(PartType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .font(AppTypography.secondary)

            HStack(spacing: AppSpacing.sm) {
                TextField("Marka", text: part.brand)
                    .font(AppTypography.secondary)
                TextField("Model", text: part.model)
                    .font(AppTypography.secondary)
            }

            Toggle("Garanti", isOn: part.hasWarranty)
                .font(AppTypography.caption)
                .tint(AppColors.accentPrimary)

            if part.hasWarranty.wrappedValue {
                DatePicker(
                    "Garanti Bitiş",
                    selection: Binding(
                        get: { part.warrantyDate.wrappedValue ?? Date() },
                        set: { part.warrantyDate.wrappedValue = $0 }
                    ),
                    displayedComponents: .date
                )
                .font(AppTypography.caption)
            }

            Divider()
        }
    }

    // MARK: - Next Reminder
    private var nextReminderSection: some View {
        Section {
            Toggle("Sonraki bakım için hatırlatıcı oluştur", isOn: $createNextReminder)
                .font(AppTypography.body)
                .tint(AppColors.accentPrimary)

            if createNextReminder {
                Picker("Hatırlatıcı Türü", selection: $nextReminderType) {
                    Text("Periyodik Bakım").tag(ReminderType.periodicService)
                    Text("Yağ Değişimi").tag(ReminderType.oilChange)
                    Text("Fren").tag(ReminderType.brakes)
                    Text("Lastik").tag(ReminderType.tire)
                    Text("Diğer").tag(ReminderType.custom)
                }
                .font(AppTypography.secondary)

                DatePicker("Tarih", selection: $nextReminderDate, displayedComponents: .date)
                    .font(AppTypography.secondary)

                labeledField("Hedef Km", icon: "gauge.with.needle", text: $nextReminderOdometerText, keyboard: .numberPad)
            }
        } header: {
            Text("Sonraki Hatırlatıcı")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Vehicle
    private var vehicleSection: some View {
        Section {
            Picker(selection: $selectedVehicleId) {
                Text("Seç").tag(nil as UUID?)
                ForEach(vehicles) { v in
                    Text(v.plate.isEmpty ? v.fullName : "\(v.plate) — \(v.fullName)")
                        .tag(v.id as UUID?)
                }
            } label: {
                Label("Araç", systemImage: "car")
            }
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Errors
    private var errorSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { error in
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.critical)
            }
        } header: {
            Text("Eksik Bilgiler").foregroundColor(AppColors.critical)
        }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - Helpers
    private func labeledField(_ label: String, icon: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon).foregroundColor(AppColors.textTertiary).frame(width: 24)
            TextField(label, text: text)
                .font(AppTypography.body).keyboardType(keyboard)
        }
    }

    private func parseCost(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(t).flatMap { $0 >= 0 ? $0 : nil }
    }

    private func loadExistingParts(for record: ServiceRecord) {
        let recordId = record.id
        if let allParts = try? modelContext.fetch(FetchDescriptor<PartChange>()) {
            changedParts = allParts.filter { $0.serviceRecordId == recordId }.map { part in
                PartDraft(
                    partType: part.partType,
                    brand: part.brand ?? "",
                    model: part.model ?? "",
                    warrantyDate: part.warrantyUntil,
                    hasWarranty: part.warrantyUntil != nil
                )
            }
        }
    }

    // MARK: - Save
    private func saveRecord() {
        var errors: [String] = []

        if selectedVehicleId == nil {
            errors.append("Bir araç seçmelisin.")
        }

        let trimmedOdometer = odometerText.trimmingCharacters(in: .whitespaces)
        if !trimmedOdometer.isEmpty {
            if let value = Int(trimmedOdometer) {
                if value < 0 {
                    errors.append("Kilometre negatif olamaz.")
                }
            } else {
                errors.append("Kilometre geçerli bir sayı olmalı.")
            }
        }

        if date > Date() {
            errors.append("Bakım tarihi gelecekte olamaz.")
        }

        if !laborCostText.trimmingCharacters(in: .whitespaces).isEmpty && laborCost == nil {
            errors.append("İşçilik tutarı geçerli bir sayı olmalı.")
        }
        if !partsCostText.trimmingCharacters(in: .whitespaces).isEmpty && partsCost == nil {
            errors.append("Parça tutarı geçerli bir sayı olmalı.")
        }
        if !totalCostText.trimmingCharacters(in: .whitespaces).isEmpty && totalCost == nil {
            errors.append("Toplam tutar geçerli bir sayı olmalı.")
        }

        if createNextReminder {
            let trimmedNextKm = nextReminderOdometerText.trimmingCharacters(in: .whitespaces)
            if !trimmedNextKm.isEmpty {
                if let value = Int(trimmedNextKm) {
                    if value < 0 {
                        errors.append("Sonraki hatırlatıcı km değeri negatif olamaz.")
                    }
                } else {
                    errors.append("Sonraki hatırlatıcı km değeri geçerli bir sayı olmalı.")
                }
            }
        }

        guard errors.isEmpty else {
            validationErrors = errors
            return
        }

        guard let vehicleId = selectedVehicleId else { return }

        let record: ServiceRecord
        if let existing = existingRecord {
            record = existing
        } else {
            record = ServiceRecord(vehicleId: vehicleId)
            modelContext.insert(record)
        }

        record.serviceTypeRaw = serviceType.rawValue
        record.date = date
        record.odometer = odometer
        record.vendorName = vendorName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : vendorName.trimmingCharacters(in: .whitespaces)
        record.laborCost = laborCost
        record.partsCost = partsCost
        record.totalCost = totalCost
        record.oilType = oilType.trimmingCharacters(in: .whitespaces).isEmpty ? nil : oilType.trimmingCharacters(in: .whitespaces)
        record.notes = notes.trimmingCharacters(in: .whitespaces)

        // Düzenleme modunda eski parçaları sil (tekrar eklemeden önce)
        if isEditing {
            let recordId = record.id
            if let allParts = try? modelContext.fetch(FetchDescriptor<PartChange>()) {
                for oldPart in allParts where oldPart.serviceRecordId == recordId {
                    modelContext.delete(oldPart)
                }
            }
        }

        // Parçaları kaydet
        for draft in changedParts {
            let part = PartChange(
                serviceRecordId: record.id,
                partType: draft.partType,
                brand: draft.brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draft.brand.trimmingCharacters(in: .whitespaces),
                model: draft.model.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draft.model.trimmingCharacters(in: .whitespaces),
                warrantyUntil: draft.hasWarranty ? draft.warrantyDate : nil
            )
            modelContext.insert(part)
        }

        // Sonraki hatırlatıcı
        if createNextReminder {
            let nextKm = Int(nextReminderOdometerText.trimmingCharacters(in: .whitespaces))
            let reminder = Reminder(
                vehicleId: vehicleId,
                type: nextReminderType,
                title: nextReminderType == .custom ? "Sonraki Bakım" : nextReminderType.displayName,
                dueDate: nextReminderDate,
                dueOdometer: nextKm,
                priority: .info
            )
            modelContext.insert(reminder)
            Task { await NotificationService.shared.scheduleReminder(reminder) }
        }

        do {
            try modelContext.save()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            dismiss()
        } catch {
            validationErrors = ["Kaydedilemedi: \(error.localizedDescription)"]
        }
    }
}

#Preview("Bakım Ekleme") {
    ServiceRecordFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
