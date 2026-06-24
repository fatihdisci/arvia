import SwiftUI
import SwiftData

// MARK: - Inspection Report View
// Ekspertiz raporu ekleme, düzenleme ve görüntüleme.
// Hukuki uyarı her zaman görünür.

struct InspectionReportFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var allDocuments: [VehicleDocument]

    let existingReport: InspectionReport?

    @State private var providerName = ""
    @State private var branchName = ""
    @State private var reportDate = Date()
    @State private var odometerText = ""
    @State private var summary = ""
    @State private var selectedVehicleId: UUID?
    @State private var selectedDocumentId: UUID?
    @State private var verificationStatus: VerificationStatus = .manual
    @State private var includeInSaleFile = true

    @State private var validationErrors: [String] = []

    init(existingReport: InspectionReport? = nil) {
        self.existingReport = existingReport
        if let r = existingReport {
            _providerName = State(initialValue: r.providerName)
            _branchName = State(initialValue: r.branchName ?? "")
            _reportDate = State(initialValue: r.reportDate)
            _odometerText = State(initialValue: r.odometer.map(String.init) ?? "")
            _summary = State(initialValue: r.summary)
            _selectedVehicleId = State(initialValue: r.vehicleId)
            _selectedDocumentId = State(initialValue: r.documentId)
            _verificationStatus = State(initialValue: r.verificationStatus)
        }
    }

    private var isEditing: Bool { existingReport != nil }
    private var availableDocuments: [VehicleDocument] {
        allDocuments.filter { $0.vehicleId == selectedVehicleId }
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                detailSection
                documentSection
                statusSection
                vehicleSection
                legalSection
                if !validationErrors.isEmpty { errorSection }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Ekspertiz Düzenle" : "Ekspertiz Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Kaydet" : "Ekle", action: save)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .onAppear {
                if !isEditing, vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
            }
        }
    }

    // MARK: - Provider
    private var providerSection: some View {
        Section {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.2").foregroundColor(AppColors.textTertiary)
                TextField("Firma adı", text: $providerName)
            }
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "mappin.and.ellipse").foregroundColor(AppColors.textTertiary)
                TextField("Şube (isteğe bağlı)", text: $branchName)
            }
        } header: {
            Text("Ekspertiz Firması")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Detail
    private var detailSection: some View {
        Section {
            DatePicker("Rapor Tarihi", selection: $reportDate, displayedComponents: .date)
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "gauge.with.needle").foregroundColor(AppColors.textTertiary)
                TextField("Km (isteğe bağlı)", text: $odometerText).keyboardType(.numberPad)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Label("Sonuç Özeti", systemImage: "doc.plaintext")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Rapor sonuç özetini yaz...", text: $summary, axis: .vertical)
                    .lineLimit(3...6)
                    .font(AppTypography.secondary)
            }
        } header: {
            Text("Rapor Detayları")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Document Link
    private var documentSection: some View {
        Section {
            if availableDocuments.isEmpty {
                HStack {
                    Image(systemName: "doc.text").foregroundColor(AppColors.textTertiary)
                    Text("Önce belge eklemelisin.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                Picker(selection: $selectedDocumentId) {
                    Text("Yok").tag(nil as UUID?)
                    ForEach(availableDocuments) { doc in
                        Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                            .tag(doc.id as UUID?)
                    }
                } label: {
                    Label("Belge", systemImage: "doc.text")
                }
            }
        } header: {
            Text("Belge Bağlantısı")
        } footer: {
            Text("Varsa ekspertiz raporunun PDF veya fotoğrafını belge olarak ekleyip buraya bağlayabilirsin.")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Verification Status
    private var statusSection: some View {
        Section {
            Picker(selection: $verificationStatus) {
                ForEach(VerificationStatus.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            } label: {
                Label("Doğrulama", systemImage: verificationStatus == .verified ? "checkmark.seal.fill" : "questionmark.circle")
            }

            if verificationStatus == .verified {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppColors.accentPrimary)
                    Text("Bu rapor partner sağlayıcı tarafından doğrulanmıştır. Rapor içeriğine ilişkin sorumluluk raporu düzenleyen sağlayıcıya aittir.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Toggle(isOn: $includeInSaleFile) {
                Label("Satış dosyasına dahil et", systemImage: "doc.richtext")
            }
            .tint(AppColors.accentPrimary)
        } header: {
            Text("Durum")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Vehicle
    private var vehicleSection: some View {
        Section {
            Picker(selection: $selectedVehicleId) {
                Text("Seç").tag(nil as UUID?)
                ForEach(vehicles) { v in
                    Text(v.plate.isEmpty ? v.fullName : "\(v.plate) — \(v.fullName)").tag(v.id as UUID?)
                }
            } label: { Label("Araç", systemImage: "car") }
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Legal
    private var legalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.warning)
                    Text("Yasal Uyarı")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.warning)
                }
                Text(InspectionReport.legalDisclaimer)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, AppSpacing.xxs)
        }
        .listRowBackground(AppColors.warningBackground.opacity(0.3))
    }

    private var errorSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { e in
                Label(e, systemImage: "exclamationmark.circle.fill")
                    .font(AppTypography.secondary).foregroundColor(AppColors.critical)
            }
        } header: { Text("Eksik Bilgiler").foregroundColor(AppColors.critical) }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - Save
    private func save() {
        var errors: [String] = []
        if providerName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Firma adı zorunludur.")
        }
        guard let vehicleId = selectedVehicleId else {
            errors.append("Bir araç seçmelisin.")
            validationErrors = errors; return
        }
        if !errors.isEmpty { validationErrors = errors; return }

        let report: InspectionReport
        if let existing = existingReport {
            report = existing
        } else {
            report = InspectionReport(vehicleId: vehicleId)
            modelContext.insert(report)
        }

        report.providerName = providerName.trimmingCharacters(in: .whitespaces)
        report.branchName = branchName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : branchName.trimmingCharacters(in: .whitespaces)
        report.reportDate = reportDate
        report.odometer = Int(odometerText.trimmingCharacters(in: .whitespaces))
        report.summary = summary.trimmingCharacters(in: .whitespaces)
        report.documentId = selectedDocumentId
        report.verificationStatusRaw = verificationStatus.rawValue

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview
#Preview("Ekspertiz Ekleme") {
    InspectionReportFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
