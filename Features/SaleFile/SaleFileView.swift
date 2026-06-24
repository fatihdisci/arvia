import SwiftUI
import SwiftData
import QuickLook

// MARK: - Sale File View
// Satış dosyası oluşturma akışı: bölüm seçimi, belge seçimi, PDF önizleme, paylaşım.

struct SaleFileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    let vehicle: Vehicle

    @Query private var allServiceRecords: [ServiceRecord]
    @Query private var allExpenses: [Expense]
    @Query private var allDocuments: [VehicleDocument]
    @Query private var allInspectionReports: [InspectionReport]

    @State private var selectedSections: Set<SaleFileSection> = [.summary, .serviceHistory, .documents, .disclaimer]
    @State private var includeExpenseSummary = true
    @State private var selectedDocumentIds: Set<UUID> = []
    @State private var includePhotos = false

    @State private var generatedPDFURL: URL?
    @State private var isGenerating = false
    @State private var showPreview = false
    @State private var showPaywall = false

    private var vehicleDocuments: [VehicleDocument] {
        allDocuments.filter { $0.vehicleId == vehicle.id }
    }
    private var vehicleServiceRecords: [ServiceRecord] {
        allServiceRecords.filter { $0.vehicleId == vehicle.id }
    }
    private var vehicleExpenses: [Expense] {
        allExpenses.filter { $0.vehicleId == vehicle.id }
    }
    private var vehicleInspections: [InspectionReport] {
        allInspectionReports.filter { $0.vehicleId == vehicle.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Kapak önizleme kartı
                    coverPreview

                    // Bölüm seçimi
                    sectionsPicker

                    // Belge seçimi
                    if !vehicleDocuments.isEmpty {
                        documentsPicker
                    }

                    // Ekspertiz
                    if !vehicleInspections.isEmpty {
                        inspectionInfo
                    }

                    // Disclaimer önizleme
                    disclaimerInfo

                    // Generate button
                    generateButton

                    // Generated PDF preview
                    if let url = generatedPDFURL {
                        pdfPreviewSection(url: url)
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Satış Dosyası")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: .saleFile)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Cover Preview
    private var coverPreview: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.vehicle, AppColors.accentPrimary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                VStack(spacing: 4) {
                    Text("Satış Dosyası")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white)
                    Text(vehicle.fullName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(vehicle.plate)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }

            Text("Aracının dijital dosyasını güvenle paylaş.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Sections
    private var sectionsPicker: some View {
        Group {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Dahil Edilecek Bölümler")

                VStack(spacing: 0) {
                    sectionToggle(.summary, "Araç Özeti", "Plaka, marka, model, km bilgileri")
                    Divider().padding(.leading, 44)
                    sectionToggle(.serviceHistory, "Bakım Geçmişi", "\(vehicleServiceRecords.count) kayıt")
                    Divider().padding(.leading, 44)
                    sectionToggle(.documents, "Belgeler", "\(vehicleDocuments.count) belge")
                    Divider().padding(.leading, 44)
                    sectionToggle(.inspectionReports, "Ekspertiz Raporu", "\(vehicleInspections.count) rapor")
                    Divider().padding(.leading, 44)
                    sectionToggle(.disclaimer, "Hukuki Uyarı", "Zorunlu yasal metin", editable: false)
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.appSurface)
                )
            }
            .padding(.horizontal, AppSpacing.screenMarginH)

            // Expense summary toggle
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Toggle(isOn: $includeExpenseSummary) {
                    Label("Masraf Özeti", systemImage: "chart.bar.fill")
                        .font(AppTypography.body)
                }
                .tint(AppColors.accentPrimary)
            }
            .padding(AppSpacing.md)
            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
    }

    private func sectionToggle(_ section: SaleFileSection, _ title: String, _ subtitle: String, editable: Bool = true) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: sectionIcon(section))
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            if editable {
                Toggle("", isOn: Binding(
                    get: { selectedSections.contains(section) },
                    set: { newValue in
                        if newValue { selectedSections.insert(section) }
                        else { selectedSections.remove(section) }
                    }
                ))
                .tint(AppColors.accentPrimary)
                .labelsHidden()
            } else {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(AppColors.success)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private func sectionIcon(_ section: SaleFileSection) -> String {
        switch section {
        case .summary: return "car"
        case .serviceHistory: return "wrench.and.screwdriver"
        case .expenses: return "chart.bar"
        case .inspectionReports: return "magnifyingglass"
        case .documents: return "folder"
        case .photos: return "photo"
        case .notes: return "pencil"
        case .disclaimer: return "info.circle"
        }
    }

    // MARK: - Documents Picker
    private var documentsPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Belgeler",
                actionTitle: selectedDocumentIds.count == vehicleDocuments.count ? "Seçimi Kaldır" : "Tümünü Seç",
                action: {
                    if selectedDocumentIds.count == vehicleDocuments.count {
                        selectedDocumentIds.removeAll()
                    } else {
                        selectedDocumentIds = Set(vehicleDocuments.map { $0.id })
                    }
                }
            )

            VStack(spacing: 0) {
                ForEach(vehicleDocuments) { doc in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: doc.type.defaultIcon)
                            .font(.body)
                            .foregroundColor(AppColors.accentPrimary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                                .font(AppTypography.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { selectedDocumentIds.contains(doc.id) },
                            set: { newValue in
                                if newValue { selectedDocumentIds.insert(doc.id) }
                                else { selectedDocumentIds.remove(doc.id) }
                            }
                        ))
                        .tint(AppColors.accentPrimary)
                        .labelsHidden()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)

                    if doc.id != vehicleDocuments.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Inspection Info
    private var inspectionInfo: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(AppColors.success)
            Text("En son ekspertiz raporu (\(vehicleInspections.first?.providerName ?? "")) dosyaya eklenecek.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Disclaimer
    private var disclaimerInfo: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Label("Hukuki Uyarı", systemImage: "info.circle.fill")
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.warning)
            Text(SaleFile.shortDisclaimer)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        Button {
            if paywallService.isPro || paywallService.canCreateSaleFile() {
                generatePDF()
            } else {
                showPaywall = true
            }
        } label: {
            HStack {
                if isGenerating {
                    ProgressView().tint(.white)
                }
                Text(isGenerating ? "Oluşturuluyor..." : "Satış Dosyasını Oluştur")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary)
        .padding(.horizontal, AppSpacing.screenMarginH)
        .disabled(isGenerating)
    }

    // MARK: - PDF Preview
    private func pdfPreviewSection(url: URL) -> some View {
        VStack(spacing: AppSpacing.sm) {
            SectionHeader(title: "Satış Dosyan Hazır")

            // PDF Preview
            Button {
                showPreview = true
            } label: {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accentPrimary)
                    Text("Önizlemek için dokun")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.accentPrimary)
                    Text(url.lastPathComponent)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.card)
                                .stroke(AppColors.accentPrimary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Share button
            ShareLink(item: url) {
                Label("Paylaş", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .quickLookPreview($generatedPDFURL)
    }

    // MARK: - Generate
    private func generatePDF() {
        isGenerating = true

        let selectedDocs = vehicleDocuments.filter { selectedDocumentIds.contains($0.id) }

        let data = PDFExportService.PDFData(
            vehicle: vehicle,
            serviceRecords: vehicleServiceRecords,
            expenses: vehicleExpenses,
            inspectionReports: vehicleInspections,
            documents: selectedDocs,
            includedSections: Array(selectedSections),
            includeExpenseSummary: includeExpenseSummary
        )

        // UI dışı işlemi arka planda yap
        DispatchQueue.global(qos: .userInitiated).async {
            let url = PDFExportService().generatePDF(data: data)
            DispatchQueue.main.async {
                generatedPDFURL = url
                isGenerating = false

                // SaleFile modelini kaydet
                let saleFile = SaleFile(
                    vehicleId: vehicle.id,
                    title: "\(vehicle.fullName) — Satış Dosyası",
                    includedSections: Array(selectedSections),
                    selectedDocumentIds: Array(selectedDocumentIds),
                    selectedInspectionReportIds: vehicleInspections.prefix(1).map { $0.id },
                    generatedPDFFileName: url.lastPathComponent
                )
                modelContext.insert(saleFile)
                try? modelContext.save()
            }
        }
    }
}

// MARK: - Preview
#Preview("Satış Dosyası") {
    SaleFileView(vehicle: MockDataProvider.previewVehicle())
        .modelContainer(MockDataProvider.previewContainer)
}
