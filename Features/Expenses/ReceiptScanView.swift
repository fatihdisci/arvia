import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Receipt Scan View
// Fiş/fatura tarama akışı (Faz 1) — tamamen cihaz üstü.
// Akış: giriş (tarayıcı/seçici) → "Fiş okunuyor…" → inceleme (sayfa küçük görselleri +
// önceden doldurulmuş düzenlenebilir form). Kaydetme Expense veya ServiceRecord oluşturur,
// bağlı bir Receipt kaydeder ve orijinal sayfaları belge kasasına ekler.
struct ReceiptScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    let preselectedVehicleId: UUID?

    init(preselectedVehicleId: UUID? = nil) {
        self.preselectedVehicleId = preselectedVehicleId
        _selectedVehicleId = State(initialValue: preselectedVehicleId)
    }

    // MARK: - Stage
    private enum Stage: Equatable {
        case choice
        case processing
        case review
    }

    @State private var stage: Stage = .choice
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var photoItems: [PhotosPickerItem] = []

    // Yakalanan sayfalar ve OCR/ayrıştırma sonuçları
    @State private var pages: [UIImage] = []
    @State private var rawOCRText = ""
    @State private var parsed = ParsedReceipt()

    // Düzenlenebilir form alanları
    @State private var selectedVehicleId: UUID?
    @State private var isMaintenance = false
    @State private var vendor = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var odometerText = ""
    @State private var category: ExpenseCategory = .other
    @State private var note = ""

    @State private var validationErrors: [String] = []

    // AI (yapay zekâ) yükseltme durumu
    @State private var aiInFlight = false
    @State private var aiNotice: String?
    @State private var aiAttempted = false
    @State private var showAIConsent = false
    // Yerel prefill sonrası taban değerler — kullanıcı düzenlemesini tespit için.
    @State private var baselineVendor = ""
    @State private var baselineAmount = ""
    @State private var baselineOdometer = ""
    @State private var baselineDate = Date()
    @State private var baselineCategory: ExpenseCategory = .other
    @State private var baselineMaintenance = false

    /// Üç koşul: Pro + AI onayı + ana toggle. AIConsentStore.isCloudAIEnabled
    /// (toggle && onay) ile Pro birlikte doğrulanır.
    private var aiAvailable: Bool {
        PaywallService.shared.isPro && AIConsentStore.shared.isCloudAIEnabled
    }

    private var amount: Double? {
        Double(amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
    private var odometer: Int? { Int(odometerText.filter { $0.isNumber }) }

    var body: some View {
        NavigationStack {
            content
                .background(Color.appBackground)
                .navigationTitle("Fiş/Fatura Tara")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("İptal") { dismiss() }
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if stage == .review {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Kaydet", action: save)
                                .buttonStyle(.borderless)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.accentPrimary)
                        }
                    }
                }
                .fullScreenCover(isPresented: $showCamera) {
                    DocumentCameraView(
                        onComplete: { images in
                            showCamera = false
                            handleCaptured(images)
                        },
                        onCancel: { showCamera = false }
                    )
                    .ignoresSafeArea()
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.pdf, .image],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
                .onChange(of: photoItems) { _, items in
                    guard !items.isEmpty else { return }
                    handlePhotoItems(items)
                }
                .onAppear {
                    if selectedVehicleId == nil, vehicles.count == 1 {
                        selectedVehicleId = vehicles.first?.id
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choice:
            choiceView
        case .processing:
            processingView
        case .review:
            reviewView
        }
    }

    // MARK: - Choice
    private var choiceView: some View {
        VStack(spacing: AppSpacing.lg) {
            // İmza motif — reticle çerçeveli tarama alanı önizlemesi.
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundColor(AppColors.accentPrimary)
                Text("Fişi çerçeveye hizala")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.heroCard)
                    .fill(AppColors.surfacePrimary)
            )
            .reticleCorners()
            .padding(.horizontal, AppSpacing.screenMarginH)

            Text("Fiş veya faturayı kameranla tara ya da galerinden seç. Metin cihazında okunur — hiçbir veri gönderilmez.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: AppSpacing.sm) {
                Button {
                    validationErrors = []
                    showCamera = true
                } label: {
                    Label("Kamera ile Tara", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.primary)

                PhotosPicker(selection: $photoItems, maxSelectionCount: 5, matching: .images) {
                    Label("Galeriden Fotoğraf", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.secondary)

                Button {
                    showFileImporter = true
                } label: {
                    Label("PDF Seç", systemImage: "doc.text")
                }
                .buttonStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)

            Spacer()
        }
        .padding(.top, AppSpacing.lg)
    }

    // MARK: - Processing
    private var processingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView()
                .tint(AppColors.accentPrimary)
                .scaleEffect(1.4)
            Text("Fiş okunuyor…")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("Metin cihazında tanınıyor")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Review
    private var reviewView: some View {
        Form {
            thumbnailsSection
            aiSection
            targetSection
            fieldsSection
            vehicleSection
            if !validationErrors.isEmpty { errorSection }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .sheet(isPresented: $showAIConsent) {
            AIConsentView(
                onAccept: {
                    UserDefaults.standard.set(true, forKey: AIConsentStore.consentKey)
                    UserDefaults.standard.set(true, forKey: AIConsentStore.enabledKey)
                    escalateToAI(userInitiated: true)
                },
                onDecline: {}
            )
        }
    }

    // MARK: - AI Section
    private var aiSection: some View {
        Section {
            Button {
                escalateToAI(userInitiated: true)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if aiInFlight {
                        ProgressView().tint(AppColors.accentPrimary)
                        Text("Yapay zekâ ile düzeltiliyor…")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Image(systemName: "sparkles").foregroundColor(AppColors.accentPrimary)
                        Text("Yapay zekâ ile düzelt")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(aiInFlight)

            if let aiNotice {
                Label(aiNotice, systemImage: "info.circle")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        } footer: {
            Text("Okuma zayıfsa yapay zekâ boş/şüpheli alanları doldurur. Metin, cihazdan çıkmadan önce maskelenir.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    private var thumbnailsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 112)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .stroke(AppColors.border, lineWidth: 0.5)
                            )
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }
        } header: {
            Text("Taranan Sayfalar (\(pages.count))")
        } footer: {
            Text("Sayfalar araç belge kasasına da eklenir.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    private var targetSection: some View {
        Section {
            Toggle(isOn: $isMaintenance) {
                Label("Bu bir bakım faturası", systemImage: "wrench.and.screwdriver")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
        } footer: {
            Text(isMaintenance
                 ? "Bakım kaydı olarak kaydedilir."
                 : "Masraf olarak kaydedilir.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    private var fieldsSection: some View {
        Section {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.2").foregroundColor(AppColors.textTertiary)
                TextField("Firma / Usta", text: $vendor)
                    .font(AppTypography.body)
            }

            HStack(spacing: AppSpacing.xs) {
                Text("₺")
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textTertiary)
                TextField("0,00", text: $amountText)
                    .font(AppTypography.amount)
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(.decimalPad)
            }

            DatePicker(selection: $date, displayedComponents: .date) {
                Label("Tarih", systemImage: "calendar").font(AppTypography.body)
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "gauge.with.needle").foregroundColor(AppColors.textTertiary)
                TextField("Km (isteğe bağlı)", text: $odometerText)
                    .keyboardType(.numberPad)
                    .font(AppTypography.body)
            }

            if !isMaintenance {
                Picker(selection: $category) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                } label: {
                    Label("Kategori", systemImage: "tag").font(AppTypography.body)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "pencil.line").foregroundColor(AppColors.textTertiary)
                TextField("Not (isteğe bağlı)", text: $note)
                    .font(AppTypography.body)
            }
        } header: {
            Text("Bilgiler")
        } footer: {
            if parsed.overallConfidence > 0 {
                Text("Otomatik dolduruldu — lütfen kontrol et.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    private var vehicleSection: some View {
        Section {
            if vehicles.isEmpty {
                Label("Önce bir araç eklemelisin.", systemImage: "exclamationmark.triangle")
                    .foregroundColor(AppColors.warning)
            } else {
                Picker(selection: $selectedVehicleId) {
                    Text("Seç").tag(nil as UUID?)
                    ForEach(vehicles) { v in
                        Text(v.plate.isEmpty ? v.fullName : "\(v.plate) — \(v.fullName)")
                            .tag(v.id as UUID?)
                    }
                } label: {
                    Label("Araç", systemImage: "car").font(AppTypography.body)
                }
            }
        } header: {
            Text("Araç")
        }
        .listRowBackground(Color.appSurface)
    }

    private var errorSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { e in
                Label(e, systemImage: "exclamationmark.circle.fill")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.critical)
            }
        } header: {
            Text("Eksik Bilgiler").foregroundColor(AppColors.critical)
        }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - Capture handling
    private func handleCaptured(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        pages = images
        runOCR()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                validationErrors = ["Dosya okunamadı."]; return
            }
            let images = DocumentScannerService.images(fromFileData: data, fileName: url.lastPathComponent)
            guard !images.isEmpty else {
                validationErrors = ["Dosyadan görüntü çıkarılamadı."]; return
            }
            pages = images
            runOCR()
        case .failure:
            validationErrors = ["Dosya seçilemedi."]
        }
    }

    private func handlePhotoItems(_ items: [PhotosPickerItem]) {
        stage = .processing
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run {
                photoItems = []
                if images.isEmpty {
                    stage = .choice
                    validationErrors = ["Fotoğraf yüklenemedi."]
                } else {
                    pages = images
                    runOCR()
                }
            }
        }
    }

    // MARK: - OCR + parse
    private func runOCR() {
        stage = .processing
        let capturedPages = pages
        Task {
            let text = await OCRService.shared.recognizeText(in: capturedPages)
            let result = ReceiptParserService.shared.parse(text)
            await MainActor.run {
                rawOCRText = text
                parsed = result
                prefill(from: result)
                stage = .review
                // Düşük güven + AI uygun ise sessizce AI'ya yükselt.
                if AIReceiptEscalation.shouldAutoEscalate(overallConfidence: result.overallConfidence, aiAvailable: aiAvailable) {
                    escalateToAI(userInitiated: false)
                }
            }
        }
    }

    private func prefill(from parsed: ParsedReceipt) {
        if let d = parsed.date { date = d }
        if let total = parsed.total {
            amountText = NSDecimalNumber(decimal: total).stringValue
        }
        if let v = parsed.vendor { vendor = v }
        if let km = parsed.odometer { odometerText = String(km) }
        if let c = parsed.category {
            category = c
            if c == .service { isMaintenance = true }
        }
        // Taban değerleri kaydet (kullanıcı düzenlemesini AI birleştirmesinde ayırt etmek için).
        baselineVendor = vendor
        baselineAmount = amountText
        baselineOdometer = odometerText
        baselineDate = date
        baselineCategory = category
        baselineMaintenance = isMaintenance
    }

    // MARK: - AI escalation
    /// Düşük güven → otomatik; kullanıcı "Yapay zekâ ile düzelt" → userInitiated.
    private func escalateToAI(userInitiated: Bool) {
        guard aiAvailable else {
            // Üç koşuldan biri eksik. Kullanıcı istediyse onay ekranını sun; oto ise sessiz.
            if userInitiated { showAIConsent = true }
            return
        }
        guard !aiInFlight else { return }
        aiAttempted = true
        aiInFlight = true
        aiNotice = nil
        let masked = PIIMaskingService.mask(rawOCRText)
        Task {
            do {
                let ai = try await AIProxyService.shared.parseReceipt(ocrText: masked)
                await MainActor.run {
                    applyAI(ai)
                    aiInFlight = false
                }
            } catch let error as AIProxyError {
                await MainActor.run {
                    aiInFlight = false
                    aiNotice = AIReceiptEscalation.notice(for: error) // .disabled → nil (sessiz)
                }
            } catch {
                await MainActor.run { aiInFlight = false }
            }
        }
    }

    /// AI alanlarını yalnızca boş/düşük güvenli ve kullanıcı düzenlememişse uygular.
    private func applyAI(_ ai: ParsedReceiptAI) {
        if let v = ai.vendor, AIReceiptMerge.shouldApply(
            currentIsEmpty: vendor.isEmpty, userEdited: vendor != baselineVendor,
            localConfidence: parsed.vendorConfidence, aiHasValue: true) {
            vendor = v
        }
        if let total = ai.total, AIReceiptMerge.shouldApply(
            currentIsEmpty: amountText.isEmpty, userEdited: amountText != baselineAmount,
            localConfidence: parsed.totalConfidence, aiHasValue: true) {
            amountText = formatAmount(total)
        }
        if let dateStr = ai.date, let parsedDate = Self.parseDMY(dateStr), AIReceiptMerge.shouldApply(
            currentIsEmpty: parsed.date == nil, userEdited: date != baselineDate,
            localConfidence: parsed.dateConfidence, aiHasValue: true) {
            date = parsedDate
        }
        if let odo = ai.odometer, AIReceiptMerge.shouldApply(
            currentIsEmpty: odometerText.isEmpty, userEdited: odometerText != baselineOdometer,
            localConfidence: parsed.odometerConfidence, aiHasValue: true) {
            odometerText = String(odo)
        }
        // Kategori: AI önerisi önden seçili gelir, kullanıcı değiştirmediyse.
        if category == baselineCategory, let aiCategory = AIReceiptMerge.category(from: ai.category) {
            category = aiCategory
        }
        // isMaintenance: net ise otomatik, belirsizse nötr.
        if let decision = AIReceiptMerge.maintenanceDecision(
            aiIsMaintenance: ai.isMaintenanceInvoice, aiCategory: ai.category,
            toggleTouched: isMaintenance != baselineMaintenance) {
            isMaintenance = decision
        }
    }

    private func formatAmount(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(value)
    }

    /// "dd.MM.yyyy" → Date.
    static func parseDMY(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd.MM.yyyy"
        return f.date(from: s)
    }

    // MARK: - Save
    private func save() {
        var errors: [String] = []
        guard let vehicleId = selectedVehicleId else {
            validationErrors = ["Bir araç seçmelisin."]; return
        }
        guard let amountValue = amount, amountValue > 0 else {
            errors.append("Geçerli bir tutar girmelisin.")
            validationErrors = errors; return
        }

        let trimmedVendor = vendor.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        // 1) Orijinal sayfaları belge kasasına ekle (mevcut DocumentStorageService akışı).
        let pageData = DocumentScannerService.jpegData(for: pages)
        let documentIds = saveToVault(vehicleId: vehicleId, pageData: pageData, isMaintenance: isMaintenance)

        // 2) Expense veya ServiceRecord oluştur.
        let receipt = Receipt(
            vehicleId: vehicleId,
            pageImagesData: pageData,
            rawOCRText: rawOCRText,
            parsedDate: parsed.date,
            parsedTotal: parsed.total,
            parsedVendor: parsed.vendor,
            parsedOdometer: parsed.odometer,
            suggestedCategory: parsed.category?.rawValue,
            confidence: parsed.overallConfidence
        )

        if isMaintenance {
            let record = ServiceRecord(
                vehicleId: vehicleId,
                serviceType: .custom,
                date: date,
                odometer: odometer,
                vendorName: trimmedVendor.isEmpty ? nil : trimmedVendor,
                totalCost: amountValue,
                notes: trimmedNote,
                documentIds: documentIds
            )
            modelContext.insert(record)
            receipt.linkedServiceRecordId = record.id
        } else {
            let expense = Expense(
                vehicleId: vehicleId,
                category: category,
                amount: amountValue,
                date: date,
                odometer: odometer,
                vendorName: trimmedVendor.isEmpty ? nil : trimmedVendor,
                note: trimmedNote,
                documentIds: documentIds
            )
            modelContext.insert(expense)
            receipt.linkedExpenseId = expense.id
        }

        modelContext.insert(receipt)

        do {
            try modelContext.save()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            Task { await VehicleContextRefreshService.refreshAfterVehicleContextChange(context: modelContext) }
            dismiss()
        } catch {
            validationErrors = ["Kaydedilemedi: \(error.localizedDescription)"]
        }
    }

    /// Sayfaları belge kasasına yazar (DocumentFormView ile aynı DocumentStorageService akışı).
    private func saveToVault(vehicleId: UUID, pageData: [Data], isMaintenance: Bool) -> [UUID] {
        var ids: [UUID] = []
        let docType: DocumentType = isMaintenance ? .serviceInvoice : .other
        for (index, data) in pageData.enumerated() {
            let doc = VehicleDocument(
                vehicleId: vehicleId,
                type: docType,
                title: pageData.count > 1 ? "Fiş — Sayfa \(index + 1)" : "Taranan Fiş",
                includeInSaleFile: false
            )
            let fileName = "\(doc.id.uuidString).jpg"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: tempURL)
                let result = try DocumentStorageService.shared.saveFile(
                    from: tempURL,
                    originalFileName: fileName,
                    documentId: doc.id
                )
                doc.localFileName = result.localFileName
                doc.originalFileName = fileName
                doc.fileSizeBytes = result.fileSize
                doc.fileData = data
                try? FileManager.default.removeItem(at: tempURL)
                modelContext.insert(doc)
                ids.append(doc.id)
            } catch {
                // Bir sayfa yazılamazsa atla — akışı durdurma.
                continue
            }
        }
        return ids
    }
}

// MARK: - Preview
#Preview("Fiş Tarama") {
    ReceiptScanView()
        .modelContainer(MockDataProvider.previewContainer)
}
