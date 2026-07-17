import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Vehicle Edit View
// Mevcut araç bilgilerini düzenleme sheet'i.

struct VehicleEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    @State private var vehicleType: VehicleType
    @State private var plate: String
    @State private var brand: String
    @State private var model: String
    @State private var nickname: String
    @State private var yearText: String
    @State private var odometerText: String
    @State private var fuelType: FuelType
    @State private var transmissionType: TransmissionType
    @State private var usageType: VehicleUsageType
    @State private var purchaseDate: Date
    @State private var purchaseOdometerText: String
    @State private var purchasePriceText: String
    @State private var notes: String
    @State private var showBrandPicker = false
    @State private var showModelPicker = false
    @State private var isCustomBrand: Bool
    @State private var isCustomModel: Bool
    // Motorcycle
    @State private var motorcycleType: MotorcycleType?
    @State private var engineCCText: String

    @State private var validationErrors: [String] = []
    @State private var showErrors = false

    // Fotoğraf yönetimi
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoImage: UIImage?
    @State private var showDeletePhotoConfirmation = false
    @State private var photoError: String?
    /// Mevcut fotoğrafı temsil eder; yoksa nil (placeholder).
    @State private var hasExistingPhoto: Bool

    private var engineCC: Int? {
        let text = engineCCText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : Int(text)
    }

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _vehicleType = State(initialValue: vehicle.vehicleType)
        _plate = State(initialValue: vehicle.plate)
        _brand = State(initialValue: vehicle.brand)
        _model = State(initialValue: vehicle.model)
        _nickname = State(initialValue: vehicle.nickname)
        _yearText = State(initialValue: vehicle.year.map { String($0) } ?? "")
        _odometerText = State(initialValue: vehicle.currentOdometer > 0 ? String(vehicle.currentOdometer) : "")
        _fuelType = State(initialValue: vehicle.fuelType)
        _transmissionType = State(initialValue: vehicle.transmissionType ?? .manual)
        _usageType = State(initialValue: vehicle.usageType)
        _purchaseDate = State(initialValue: vehicle.purchaseDate ?? Date())
        _purchaseOdometerText = State(initialValue: vehicle.purchaseOdometer.map { String($0) } ?? "")
        _purchasePriceText = State(initialValue: vehicle.purchasePrice.map { String(Int($0)) } ?? "")
        _notes = State(initialValue: vehicle.notes)
        _motorcycleType = State(initialValue: vehicle.motorcycleType)
        _engineCCText = State(initialValue: vehicle.engineCC.map { String($0) } ?? "")
        let catalogBrand = CarCatalogService.shared.brand(named: vehicle.brand)
        _isCustomBrand = State(initialValue: catalogBrand == nil)
        _isCustomModel = State(initialValue: catalogBrand.flatMap { CarCatalogService.shared.model(named: vehicle.model, in: $0) } == nil)
        _hasExistingPhoto = State(initialValue: vehicle.photoFileName != nil)
    }

    private var year: Int? { Int(yearText.sanitizedIntInput()) }
    private var odometer: Int? { Int(odometerText.sanitizedIntInput()) }
    private var purchaseOdometer: Int? {
        let t = purchaseOdometerText.sanitizedIntInput()
        return t.isEmpty ? nil : Int(t)
    }
    private var purchasePrice: Double? {
        let t = purchasePriceText.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : Double(t)
    }

    private var selectedCatalogBrand: CarBrand? {
        isCustomBrand ? nil : CarCatalogService.shared.brand(named: brand)
    }

    private let maxPhotoBytes = 20 * 1024 * 1024

    var body: some View {
        NavigationStack {
            Form {
                // Temel bilgiler
                Section {
                    labeledField("Plaka", icon: "number", text: $plate)
                        .textInputAutocapitalization(.characters)

                    VehicleCatalogSelectionField(
                        title: "Marka",
                        value: brand,
                        placeholder: "Marka seç",
                        systemImage: "car",
                        action: { showBrandPicker = true }
                    )

                    if isCustomBrand {
                        labeledField("Marka adı", icon: "pencil", text: $brand)
                    }

                    VehicleCatalogSelectionField(
                        title: "Model",
                        value: model,
                        placeholder: brand.isEmpty ? "Önce marka seç" : "Model seç",
                        systemImage: "tag",
                        isDisabled: brand.isEmpty && !isCustomBrand,
                        action: {
                            if isCustomBrand {
                                isCustomModel = true
                            } else if selectedCatalogBrand != nil {
                                showModelPicker = true
                            }
                        }
                    )

                    if isCustomModel || isCustomBrand {
                        labeledField("Model adı", icon: "pencil", text: $model)
                    }

                    labeledField("Yıl", icon: "calendar", text: $yearText, keyboard: .numberPad)
                    labeledField("Güncel Km", icon: "gauge.with.needle", text: $odometerText, keyboard: .numberPad)
                    labeledField("Takma ad", icon: "heart", text: $nickname)
                } header: {
                    Text("Temel Bilgiler")
                }

                // Araç türü
                Section {
                    Picker(selection: $vehicleType) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: type.heroSymbol)
                                    .font(.body)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    } label: {
                        Label("Araç Türü", systemImage: "steeringwheel")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .onChange(of: vehicleType) { _, newType in
                        if newType == .car {
                            motorcycleType = nil
                            engineCCText = ""
                        }
                    }
                } header: {
                    Text("Araç Türü")
                }

                // Motosiklet özel alanları
                if vehicleType == .motorcycle {
                    Section {
                        Picker(selection: $motorcycleType) {
                            Text("Seç (isteğe bağlı)").tag(nil as MotorcycleType?)
                            ForEach(MotorcycleType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type as MotorcycleType?)
                            }
                        } label: {
                            Label("Motosiklet Tipi", systemImage: "gauge.with.needle")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                        }

                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "engine.combustion")
                                .foregroundColor(AppColors.textTertiary)
                                .frame(width: 24)
                            TextField("Motor Hacmi (cc)", text: $engineCCText)
                                .font(AppTypography.body)
                                .keyboardType(.decimalPad)
                            if !engineCCText.isEmpty {
                                Text("cc")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    } header: {
                        Text("Motosiklet Bilgileri")
                    }
                }

                // Tip bilgileri
                Section {
                    enumPicker("Yakıt Tipi", icon: "fuelpump", selection: $fuelType)
                    enumPicker("Vites", icon: "gearshape", selection: $transmissionType)
                    enumPicker("Kullanım", icon: "person", selection: $usageType)
                } header: {
                    Text("Araç Özellikleri")
                }

                // Satın alma bilgileri
                Section {
                    DatePicker(selection: $purchaseDate, displayedComponents: .date) {
                        Label("Satın Alma Tarihi", systemImage: "cart")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    labeledField("Satın Alma Km", icon: "gauge.with.needle", text: $purchaseOdometerText, keyboard: .numberPad)
                    labeledField("Satın Alma Fiyatı (₺)", icon: "banknote", text: $purchasePriceText, keyboard: .decimalPad)
                } header: {
                    Text("Satın Alma Bilgileri")
                }

                // Notlar
                Section {
                    TextField("Notlar", text: $notes, axis: .vertical)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3...6)
                } header: {
                    Text("Notlar")
                }

                // Araç Fotoğrafı
                Section {
                    if let image = selectedPhotoImage {
                        // Yeni seçilen fotoğraf önizleme
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))

                        Button {
                            selectedPhotoItem = nil
                            selectedPhotoImage = nil
                            photoError = nil
                        } label: {
                            Label("Seçimi İptal Et", systemImage: "xmark.circle")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.critical)
                        }
                    } else if hasExistingPhoto, let fileName = vehicle.photoFileName,
                              let existingImage = VehiclePhotoStorageService.shared.loadPhoto(fileName: fileName, syncedData: vehicle.photoData) {
                        // Mevcut kayıtlı fotoğraf önizleme
                        Image(uiImage: existingImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))

                        HStack(spacing: AppSpacing.md) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Fotoğrafı Değiştir", systemImage: "arrow.triangle.2.circlepath")
                                    .font(AppTypography.secondary)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(AppColors.accentPrimary)

                            Button(role: .destructive) {
                                showDeletePhotoConfirmation = true
                            } label: {
                                Label("Fotoğrafı Sil", systemImage: "trash")
                                    .font(AppTypography.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        // Fotoğraf yok — ekle butonu
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "camera")
                                    .font(.body)
                                    .foregroundColor(AppColors.textTertiary)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(AppColors.backgroundSecondary))
                                Text("Fotoğraf Ekle")
                                    .font(AppTypography.secondary)
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderless)
                    }

                    if let error = photoError {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.critical)
                    }
                } header: {
                    Text("Araç Fotoğrafı")
                }

                // Validasyon hataları
                if showErrors && !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(AppColors.critical)
                                Text(LocalizedStringKey(error))
                                    .font(AppTypography.secondary)
                                    .foregroundColor(AppColors.critical)
                            }
                        }
                    } header: {
                        Text("Düzeltilmesi Gerekenler")
                            .foregroundColor(AppColors.critical)
                    }
                    .listRowBackground(AppColors.criticalBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: saveChanges)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(canSave ? AppColors.accentPrimary : AppColors.textTertiary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showBrandPicker) {
                CarBrandPickerSheet(service: CarCatalogService.shared, selectedBrand: brand) { selectedBrand in
                    handleBrandSelection(selectedBrand)
                }
            }
            .sheet(isPresented: $showModelPicker) {
                if let selectedCatalogBrand {
                    CarModelPickerSheet(service: CarCatalogService.shared, brand: selectedCatalogBrand, selectedModel: model) { selectedModel in
                        handleModelSelection(selectedModel)
                    }
                }
            }
            .confirmationDialog("Fotoğraf silinsin mi?", isPresented: $showDeletePhotoConfirmation) {
                Button("Fotoğrafı Sil", role: .destructive) {
                    if let fileName = vehicle.photoFileName {
                        VehiclePhotoStorageService.shared.deletePhoto(fileName: fileName)
                    }
                    vehicle.photoFileName = nil
                    vehicle.photoData = nil
                    hasExistingPhoto = false
                    selectedPhotoImage = nil
                    selectedPhotoItem = nil
                    photoError = nil
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Bu işlem geri alınamaz. Fotoğraf kalıcı olarak silinir.")
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let item = newItem { loadEditPhotoItem(item) }
            }
        }
    }

    // MARK: - Form helpers
    private func labeledField(_ label: String, icon: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)
            TextField(label, text: text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboard)
        }
    }

    private func enumPicker<T: CaseIterable & Hashable>(
        _ label: String, icon: String, selection: Binding<T>
    ) -> some View where T.AllCases: RandomAccessCollection, T: RawRepresentable, T.RawValue == String {
        Picker(selection: selection) {
            ForEach(T.allCases as! [T], id: \.self) { item in
                Text(item.rawValue).tag(item)
            }
        } label: {
            Label(label, systemImage: icon)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    // MARK: - Catalog Selection
    private func handleBrandSelection(_ selectedBrand: CarBrand?) {
        if let selectedBrand {
            var selection = VehicleCatalogSelection(brand: brand, model: model)
            selection.selectBrand(selectedBrand.displayName)
            brand = selection.brand
            model = selection.model
            isCustomBrand = false
            isCustomModel = false
        } else {
            brand = ""
            model = ""
            isCustomBrand = true
            isCustomModel = true
        }
    }

    private func handleModelSelection(_ selectedModel: CarModel?) {
        if let selectedModel {
            model = selectedModel.displayName
            isCustomModel = false
        } else {
            model = ""
            isCustomModel = true
        }
    }

    // MARK: - Save
    /// Kaydet için kesin zorunlu alanların (plaka, marka, model) boş olmaması.
    /// Plaka uzunluğu/yıl aralığı gibi format doğrulamaları kaydetme anındaki
    /// hata mesajlarında ele alınır (fazla kapatma yok).
    private var canSave: Bool {
        !plate.trimmingCharacters(in: .whitespaces).isEmpty
            && !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveChanges() {
        let errors = validate()
        if errors.isEmpty {
            if applyChanges() {
                dismiss()
            }
        } else {
            validationErrors = errors
            showErrors = true
        }
    }

    private func validate() -> [String] {
        var errors: [String] = []

        let p = plate.trimmingCharacters(in: .whitespaces)
        if p.isEmpty {
            errors.append("Plaka zorunludur.")
        } else if p.count < 6 {
            errors.append("Plaka geçerli bir plaka numarası olmalıdır.")
        }

        if brand.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Marka zorunludur.")
        }
        if model.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Model zorunludur.")
        }

        if let y = year {
            let currentYear = Calendar.current.component(.year, from: Date())
            if y < 1900 || y > currentYear + 1 {
                errors.append("Yıl 1900 ile \(currentYear + 1) arasında olmalıdır.")
            }
        }

        if let odo = odometer, odo < 0 {
            errors.append("Km sıfırdan küçük olamaz.")
        }

        return errors
    }

    private func applyChanges() -> Bool {
        let oldPhotoFileName = vehicle.photoFileName
        var newPhotoFileName: String?

        // Fotoğraf: yeni seçildiyse kaydet, değişmediyse dokunma
        if let newImage = selectedPhotoImage {
            do {
                let saved = try VehiclePhotoStorageService.shared.savePhotoReturningData(newImage)
                newPhotoFileName = saved.fileName
                vehicle.photoFileName = saved.fileName
                vehicle.photoData = saved.data
            } catch {
                photoError = error.localizedDescription
                return false
            }
        }

        vehicle.vehicleTypeRaw = vehicleType.rawValue
        vehicle.plate = plate.trimmingCharacters(in: .whitespaces).uppercased()
        vehicle.brand = brand.trimmingCharacters(in: .whitespaces)
        vehicle.model = model.trimmingCharacters(in: .whitespaces)
        vehicle.nickname = nickname.trimmingCharacters(in: .whitespaces)
        vehicle.year = year
        vehicle.currentOdometer = odometer ?? vehicle.currentOdometer
        vehicle.fuelType = fuelType
        vehicle.transmissionType = transmissionType
        vehicle.usageType = usageType
        vehicle.purchaseDate = purchaseDate
        vehicle.purchaseOdometer = purchaseOdometer
        vehicle.purchasePrice = purchasePrice
        vehicle.notes = notes
        vehicle.motorcycleTypeRaw = vehicleType == .motorcycle ? motorcycleType?.rawValue : nil
        vehicle.engineCC = vehicleType == .motorcycle ? engineCC : nil

        do {
            try modelContext.save()
            if let oldPhotoFileName,
               let newPhotoFileName,
               oldPhotoFileName != newPhotoFileName {
                VehiclePhotoStorageService.shared.deletePhoto(fileName: oldPhotoFileName)
            }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            Task { await VehicleContextRefreshService.refreshAfterVehicleContextChange(context: modelContext) }
        } catch {
            modelContext.rollback()
            if let newPhotoFileName {
                VehiclePhotoStorageService.shared.deletePhoto(fileName: newPhotoFileName)
            }
            validationErrors = ["Kaydedilemedi: \(error.localizedDescription)"]
            return false
        }
        return true
    }

    // MARK: - Photo Handling
    private func loadEditPhotoItem(_ item: PhotosPickerItem) {
        photoError = nil
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw VehiclePhotoSelectionError.unreadable
                }
                guard data.count <= maxPhotoBytes else {
                    throw VehiclePhotoSelectionError.tooLarge
                }
                guard let image = UIImage(data: data) else {
                    throw VehiclePhotoSelectionError.decodeFailed
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                    selectedPhotoImage = image
                    photoError = nil
                }
            } catch {
                await MainActor.run {
                    selectedPhotoItem = nil
                    selectedPhotoImage = nil
                    photoError = (error as? LocalizedError)?.errorDescription ?? "Fotoğraf okunamadı. Lütfen farklı bir görsel seç."
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Düzenleme") {
    VehicleEditView(vehicle: MockDataProvider.previewVehicle())
}
