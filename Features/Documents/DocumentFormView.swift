import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Document Form View
// Belge ekleme formu: tip, başlık, fotoğraf/PDF seçimi, tarihler, satış dosyası toggle.

struct DocumentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var allReminders: [Reminder]

    let existingDocument: VehicleDocument?

    @State private var documentType: DocumentType = .other
    @State private var title = ""
    @State private var selectedVehicleId: UUID?
    @State private var issueDate: Date?
    @State private var expiryDate: Date?
    @State private var vendorName = ""
    @State private var includeInSaleFile = false
    @State private var hasIssueDate = false
    @State private var hasExpiryDate = false
    @State private var createExpiryReminder = true

    // Dosya seçimi
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var importedFileURL: URL?
    @State private var importedFileName: String?
    @State private var importedFileData: Data?

    @State private var validationErrors: [String] = []
    @State private var isImporting = false

    /// Başlık kullanıcı tarafından elle düzenlendiyse true.
    /// Tip değişiminde başlığı otomatik güncellemeyi durdurur.
    @State private var hasUserEditedTitle = false
    /// Otomatik atanan son başlık. Kullanıcı düzenlediyse bu değer güncelliğini yitirir.
    @State private var lastAutoTitle = ""

    init(existingDocument: VehicleDocument? = nil, preselectedVehicleId: UUID? = nil) {
        self.existingDocument = existingDocument
        if let doc = existingDocument {
            _documentType = State(initialValue: doc.type)
            _title = State(initialValue: doc.title)
            _hasUserEditedTitle = State(initialValue: true) // düzenleme modunda başlık zaten kullanıcıya ait
            _selectedVehicleId = State(initialValue: doc.vehicleId)
            _issueDate = State(initialValue: doc.issueDate)
            _expiryDate = State(initialValue: doc.expiryDate)
            _vendorName = State(initialValue: doc.vendorName ?? "")
            _includeInSaleFile = State(initialValue: doc.includeInSaleFile)
            _hasIssueDate = State(initialValue: doc.issueDate != nil)
            _hasExpiryDate = State(initialValue: doc.expiryDate != nil)
            _createExpiryReminder = State(initialValue: false)
            _importedFileName = State(initialValue: doc.originalFileName)
        } else {
            // Yeni belge: varsayılan tipin adını başlık olarak ata
            let defaultTitle = DocumentType.other.displayName
            _title = State(initialValue: defaultTitle)
            _lastAutoTitle = State(initialValue: defaultTitle)
            if let vid = preselectedVehicleId {
                _selectedVehicleId = State(initialValue: vid)
            }
        }
    }

    private var isEditing: Bool { existingDocument != nil }
    private var hasExistingFile: Bool { existingDocument?.localFileName.isEmpty == false }

    /// Kaydet için kesin zorunlu alanlar: başlık, araç ve (yeni kayıtta) seçili dosya.
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedVehicleId != nil
            && (isEditing || importedFileData != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailsSection
                fileSection
                saleFileSection
                vehicleSection
                if !validationErrors.isEmpty { errorSection }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Belge Düzenle" : "Belge Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Kaydet" : "Ekle", action: saveDocument)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor((canSave && !isImporting) ? AppColors.accentPrimary : AppColors.textTertiary)
                        .disabled(!canSave || isImporting)
                }
            }
            .onAppear {
                if !isEditing, vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
                if let documentId = existingDocument?.id {
                    createExpiryReminder = allReminders.contains {
                        $0.sourceDocumentId == documentId
                            && $0.statusRaw != ReminderStatus.completed.rawValue
                            && $0.statusRaw != ReminderStatus.archived.rawValue
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let item = newItem { handlePhotoSelection(item) }
            }
            .onChange(of: documentType) { _, newType in
                updateAutomaticTitle(for: newType)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - Type
    /// Seçili aracın vehicleType'ına göre filtrelenmiş belge türleri.
    private var availableDocumentTypes: [DocumentType] {
        guard let vid = selectedVehicleId, let vehicle = vehicles.first(where: { $0.id == vid }) else {
            return DocumentType.availableTypes(for: nil) + [.other]
        }
        return DocumentType.availableTypes(for: vehicle.vehicleType) + [.other]
    }

    private var typeSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: AppSpacing.xs) {
                ForEach(availableDocumentTypes, id: \.self) { type in
                    docTypeButton(type)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
        } header: {
            Text("Belge Türü")
        }
        .listRowBackground(Color.appSurface)
    }

    private func docTypeButton(_ type: DocumentType) -> some View {
        Button {
            documentType = type
        } label: {
            VStack(spacing: 3) {
                Image(systemName: type.defaultIcon)
                    .font(.body)
                    .foregroundColor(documentType == type ? .white : AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(documentType == type ? AppColors.accentPrimary : AppColors.backgroundSecondary)
                    )
                Text(type.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(documentType == type ? AppColors.accentPrimary : AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details
    private var detailsSection: some View {
        Section {
            TextField("Başlık", text: Binding(
                get: { title },
                set: { newValue in
                    title = newValue
                    // Kullanıcı elle yazdıysa otomatik güncellemeyi durdur
                    if newValue != lastAutoTitle {
                        hasUserEditedTitle = true
                    }
                }
            ))
                .font(AppTypography.body)

            Toggle(isOn: $hasIssueDate) { Label("Düzenleme Tarihi", systemImage: "calendar") }
                .tint(AppColors.accentPrimary)
            if hasIssueDate {
                DatePicker("Tarih", selection: Binding(get: { issueDate ?? Date() }, set: { issueDate = $0 }), displayedComponents: .date)
            }

            Toggle(isOn: $hasExpiryDate) { Label("Son Kullanma Tarihi", systemImage: "calendar.badge.exclamationmark") }
                .tint(AppColors.accentPrimary)
            if hasExpiryDate {
                DatePicker("Tarih", selection: Binding(get: { expiryDate ?? Date() }, set: { expiryDate = $0 }), displayedComponents: .date)

                Toggle(isOn: $createExpiryReminder) {
                    Label("Bitiş için hatırlat", systemImage: "bell.badge")
                }
                .tint(AppColors.accentPrimary)

                if createExpiryReminder {
                    Text("\(documentType.expiryReminderTitle) işi otomatik oluşturulur ve belgeyle birlikte güncellenir.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.2").foregroundColor(AppColors.textTertiary)
                TextField("Firma (isteğe bağlı)", text: $vendorName)
            }
        } header: { Text("Detaylar") }
        .listRowBackground(Color.appSurface)
    }

    private func updateAutomaticTitle(for type: DocumentType) {
        guard !isEditing, !hasUserEditedTitle else { return }
        title = type.displayName
        lastAutoTitle = type.displayName
    }

    // MARK: - File Selection
    private var fileSection: some View {
        Section {
            if isEditing && hasExistingFile && importedFileData == nil {
                HStack {
                    Image(systemName: "doc.fill").foregroundColor(AppColors.success)
                    Text(existingDocument?.originalFileName ?? "Mevcut dosya")
                        .font(AppTypography.secondary)
                    Spacer()
                    Text("Yüklü")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.success)
                }
                Text("Yeni dosya seçersen mevcut dosya değiştirilir.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            if let fileName = importedFileName {
                HStack {
                    Image(systemName: fileName.hasSuffix(".pdf") ? "doc.fill" : "photo.fill")
                        .foregroundColor(AppColors.success)
                    Text(fileName)
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Button("Kaldır") {
                        importedFileURL = nil
                        importedFileName = nil
                        importedFileData = nil
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.critical)
                }
            }

            HStack(spacing: AppSpacing.lg) {
                // Fotoğraf seçimi
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accentPrimary)
                        Text("Fotoğraf")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppRadius.small).fill(AppColors.accentPrimary.opacity(0.06)))
                }

                // PDF seçimi
                Button { showFileImporter = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accentPrimary)
                        Text("PDF")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppRadius.small).fill(AppColors.accentPrimary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(isEditing ? "Dosya" : "Dosya Seç")
        } footer: {
            Text("Fotoğraf veya PDF dosyası ekleyebilirsin. Maksimum 20 MB.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Sale File
    private var saleFileSection: some View {
        Section {
            Toggle(isOn: $includeInSaleFile) {
                Label("Satış dosyasına dahil et", systemImage: "doc.richtext")
                    .font(AppTypography.body)
            }
            .tint(AppColors.accentPrimary)
        } footer: {
            Text("Satış dosyası oluştururken bu belge otomatik olarak eklenir.")
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

    private var errorSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { e in
                Label(e, systemImage: "exclamationmark.circle.fill")
                    .font(AppTypography.secondary).foregroundColor(AppColors.critical)
            }
        } header: { Text("Eksik Bilgiler").foregroundColor(AppColors.critical) }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - File Handling
    private func handlePhotoSelection(_ item: PhotosPickerItem) {
        isImporting = true
        Task {
            guard let raw = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    validationErrors = ["Fotoğraf okunamadı. Lütfen tekrar dene."]
                    isImporting = false
                }
                return
            }
            // Büyük fotoğrafları ana thread dışında küçült/yeniden kodla; başarısız
            // olursa orijinaline geri düş (yine de 20 MB sınırı uygulanır).
            let optimized = await Task.detached(priority: .userInitiated) {
                ImageOptimizer.optimizedJPEGData(from: raw) ?? raw
            }.value

            await MainActor.run {
                guard optimized.count < 20_971_520 else { // 20 MB
                    validationErrors = ["Dosya 20 MB'dan büyük olamaz."]
                    isImporting = false
                    return
                }
                importedFileData = optimized
                // Yeniden kodlandığı için her zaman .jpg — saklanan dosya uzantısı
                // bununla belirlenir (DocumentStorageService).
                importedFileName = "Belge_\(Self.fileTimestamp()).jpg"
                isImporting = false
            }
        }
    }

    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url), data.count < 20_971_520 {
                importedFileData = data
                importedFileURL = url
                importedFileName = url.lastPathComponent
            } else {
                validationErrors = ["Dosya 20 MB'dan büyük olamaz veya okunamadı."]
            }
        case .failure:
            validationErrors = ["Dosya seçilemedi."]
        }
    }

    // MARK: - Save
    private func saveDocument() {
        var errors: [String] = []
        let t = title.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { errors.append("Başlık zorunludur.") }
        guard let vehicleId = selectedVehicleId else {
            errors.append("Bir araç seçmelisin.")
            validationErrors = errors; return
        }
        if !isEditing, importedFileData == nil {
            errors.append("Bir dosya seçmelisin.")
        }
        if !errors.isEmpty { validationErrors = errors; return }

        let doc: VehicleDocument
        if let existing = existingDocument {
            doc = existing
        } else {
            doc = VehicleDocument(vehicleId: vehicleId)
            modelContext.insert(doc)
        }

        let originalLocalFileName = existingDocument?.localFileName
        let originalFileData = originalLocalFileName.flatMap {
            DocumentStorageService.shared.readFileData($0)
        } ?? existingDocument?.fileData
        var savedLocalFileName: String?

        doc.typeRaw = documentType.rawValue
        doc.title = t
        doc.vehicleId = vehicleId
        doc.issueDate = hasIssueDate ? issueDate : nil
        doc.expiryDate = hasExpiryDate ? expiryDate : nil
        doc.vendorName = vendorName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : vendorName.trimmingCharacters(in: .whitespaces)
        doc.includeInSaleFile = includeInSaleFile

        let activeLinkedReminders = allReminders.filter {
            $0.sourceDocumentId == doc.id
                && $0.statusRaw != ReminderStatus.completed.rawValue
                && $0.statusRaw != ReminderStatus.archived.rawValue
        }
        let activeLinkedReminder = activeLinkedReminders.first
        var reminderIDsToCancel: [UUID] = []
        if hasExpiryDate, createExpiryReminder, let expiryDate {
            let reminder: Reminder
            if let activeLinkedReminder {
                reminder = activeLinkedReminder
            } else {
                reminder = Reminder(
                    vehicleId: vehicleId,
                    sourceDocumentId: doc.id
                )
                modelContext.insert(reminder)
            }
            reminder.vehicleId = vehicleId
            reminder.type = documentType.expiryReminderType
            reminder.title = documentType.expiryReminderTitle
            reminder.dueDate = expiryDate
            reminder.dueOdometer = nil
            reminder.repeatRuleRaw = nil
            reminder.priority = .warning
            reminder.status = .active
            reminder.completedAt = nil
            reminder.addedToHistoryAt = nil
            reminder.notes = "Belge bitiş tarihinden otomatik oluşturuldu."
            reminder.sourceDocumentId = doc.id

            // Bozuk/yarım kalmış eski bir işlem birden fazla otomatik kayıt bıraktıysa
            // tek kaynak belge için yalnızca bir aktif hatırlatıcı koru.
            for duplicate in activeLinkedReminders.dropFirst() {
                reminderIDsToCancel.append(duplicate.id)
                modelContext.delete(duplicate)
            }
        } else {
            for linkedReminder in activeLinkedReminders {
                reminderIDsToCancel.append(linkedReminder.id)
                modelContext.delete(linkedReminder)
            }
        }

        // Analytics: yalnızca yeni bir dosya yükleniyorsa upload event'leri anlamlı.
        let isFileUpload = importedFileData != nil
        let docCategoryParams: [AnalyticsParameterKey: AnalyticsParameterValue] =
            [.documentCategory: .string(String(describing: documentType))]

        // Yeni dosya varsa kaydet
        if let data = importedFileData, let fileName = importedFileName {
            AnalyticsService.shared.log(.documentUploadStarted, parameters: docCategoryParams)
            // Geçici dosya oluştur
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            do {
                try data.write(to: tempURL)
            } catch {
                modelContext.rollback()
                AnalyticsService.shared.log(.documentUploadFailed, parameters: docCategoryParams)
                errors.append("Geçici dosya oluşturulamadı: \(error.localizedDescription)")
                validationErrors = errors; return
            }

            do {
                let result = try DocumentStorageService.shared.saveFile(
                    from: tempURL,
                    originalFileName: fileName,
                    documentId: doc.id
                )
                savedLocalFileName = result.localFileName
                doc.localFileName = result.localFileName
                doc.originalFileName = fileName
                doc.fileSizeBytes = result.fileSize
                // CloudKit senkron yansıması (externalStorage → CKAsset).
                // Veri zaten bellekte; tekrar diskten okumaya gerek yok.
                doc.fileData = data

            } catch {
                modelContext.rollback()
                AnalyticsService.shared.log(.documentUploadFailed, parameters: docCategoryParams)
                errors.append("Dosya kaydedilemedi: \(error.localizedDescription)")
                validationErrors = errors; return
            }
        }

        do {
            try modelContext.save()
            if isFileUpload {
                AnalyticsService.shared.log(.documentUploadCompleted, parameters: docCategoryParams)
            }
            NotificationService.shared.cancelReminders(ids: reminderIDsToCancel)
            if let originalLocalFileName,
               let savedLocalFileName,
               originalLocalFileName != savedLocalFileName {
                try? DocumentStorageService.shared.deleteFile(originalLocalFileName)
            }
            // Başarı haptik
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            Task { await NotificationRefreshService.refreshAll(context: modelContext) }
            dismiss()
        } catch {
            modelContext.rollback()
            if let savedLocalFileName {
                if savedLocalFileName == originalLocalFileName,
                   let originalFileData {
                    do {
                        try DocumentStorageService.shared.writeFileData(
                            originalFileData,
                            localFileName: savedLocalFileName
                        )
                    } catch {
                        errors.append("Önceki dosya geri yüklenemedi.")
                    }
                } else {
                    try? DocumentStorageService.shared.deleteFile(savedLocalFileName)
                }
            }
            if isFileUpload {
                AnalyticsService.shared.log(.documentUploadFailed, parameters: docCategoryParams)
            }
            errors.append("Kayıt sırasında bir hata oluştu. Lütfen tekrar dene.")
            validationErrors = errors
        }
    }
}

#Preview("Belge Ekleme") {
    DocumentFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
