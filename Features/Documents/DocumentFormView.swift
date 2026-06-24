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

    // Dosya seçimi
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var importedFileURL: URL?
    @State private var importedFileName: String?
    @State private var importedFileData: Data?

    @State private var validationErrors: [String] = []
    @State private var isImporting = false

    init(existingDocument: VehicleDocument? = nil) {
        self.existingDocument = existingDocument
        if let doc = existingDocument {
            _documentType = State(initialValue: doc.type)
            _title = State(initialValue: doc.title)
            _selectedVehicleId = State(initialValue: doc.vehicleId)
            _issueDate = State(initialValue: doc.issueDate)
            _expiryDate = State(initialValue: doc.expiryDate)
            _vendorName = State(initialValue: doc.vendorName ?? "")
            _includeInSaleFile = State(initialValue: doc.includeInSaleFile)
            _hasIssueDate = State(initialValue: doc.issueDate != nil)
            _hasExpiryDate = State(initialValue: doc.expiryDate != nil)
            _importedFileName = State(initialValue: doc.originalFileName)
        }
    }

    private var isEditing: Bool { existingDocument != nil }
    private var hasExistingFile: Bool { existingDocument?.localFileName.isEmpty == false }

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
                        .foregroundColor(AppColors.accentPrimary)
                        .disabled(isImporting)
                }
            }
            .onAppear {
                if !isEditing, vehicles.count == 1 {
                    selectedVehicleId = vehicles.first?.id
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let item = newItem { handlePhotoSelection(item) }
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
    private var typeSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: AppSpacing.xs) {
                ForEach(DocumentType.allCases, id: \.self) { type in
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
            if title.isEmpty { title = type.displayName }
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
            TextField("Başlık", text: $title)
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
            }

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.2").foregroundColor(AppColors.textTertiary)
                TextField("Firma (isteğe bağlı)", text: $vendorName)
            }
        } header: { Text("Detaylar") }
        .listRowBackground(Color.appSurface)
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
            if let data = try? await item.loadTransferable(type: Data.self),
               data.count < 20_971_520 { // 20 MB limit
                await MainActor.run {
                    importedFileData = data
                    importedFileName = item.itemIdentifier ?? "photo.jpg"
                    isImporting = false
                }
            } else {
                await MainActor.run {
                    validationErrors = ["Dosya 20 MB'dan büyük olamaz."]
                    isImporting = false
                }
            }
        }
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

        doc.typeRaw = documentType.rawValue
        doc.title = t
        doc.vehicleId = vehicleId
        doc.issueDate = hasIssueDate ? issueDate : nil
        doc.expiryDate = hasExpiryDate ? expiryDate : nil
        doc.vendorName = vendorName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : vendorName.trimmingCharacters(in: .whitespaces)
        doc.includeInSaleFile = includeInSaleFile

        // Yeni dosya varsa kaydet
        if let data = importedFileData, let fileName = importedFileName {
            // Geçici dosya oluştur
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try? data.write(to: tempURL)

            do {
                let result = try DocumentStorageService.shared.saveFile(
                    from: tempURL,
                    originalFileName: fileName,
                    documentId: doc.id
                )
                doc.localFileName = result.localFileName
                doc.originalFileName = fileName
                doc.fileSizeBytes = result.fileSize

                // Geçiciyi temizle
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                errors.append("Dosya kaydedilemedi: \(error.localizedDescription)")
                validationErrors = errors; return
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview("Belge Ekleme") {
    DocumentFormView()
        .modelContainer(MockDataProvider.previewContainer)
}
