import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Vehicle Form View
// Yeni araç ekleme formu. Sheet olarak sunulur.
// Design kurallarına uygun: token tabanlı spacing/renk, Türkçe metin, validasyon.

struct VehicleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    // MARK: Required fields
    @State private var vehicleType: VehicleType = .car
    @State private var plate = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var odometerText = ""
    @State private var fuelType: FuelType = .gasoline
    @State private var usageType: VehicleUsageType = .personal
    @State private var transmissionType: TransmissionType = .automatic

    // MARK: Motorcycle-specific
    @State private var motorcycleType: MotorcycleType? = nil
    @State private var engineCCText = ""

    // MARK: Optional fields
    @State private var nickname = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoImage: UIImage?
    @State private var photoError: String?
    @State private var showBrandPicker = false
    @State private var showModelPicker = false
    @State private var isCustomBrand = false
    @State private var isCustomModel = false

    // MARK: Purchase info (optional)
    @State private var addPurchaseInfo = false
    @State private var purchaseDate = Date()
    @State private var purchaseOdometerText = ""
    @State private var purchasePriceText = ""

    // MARK: First reminders (optional)
    @State private var addInspectionReminder = false
    @State private var inspectionDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()

    @State private var addInsuranceReminder = false
    @State private var insuranceDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var addCascoReminder = false
    @State private var cascoDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var addLastServiceReminder = false
    @State private var lastServiceDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var lastServiceOdometerText = ""

    // MARK: Validation
    @State private var validationErrors: [String] = []
    @State private var showErrors = false
    @State private var showPaywall = false

    // MARK: Computed
    private var year: Int? { Int(yearText.sanitizedIntInput()) }
    private var odometer: Int? { Int(odometerText.sanitizedIntInput()) }
    private var lastServiceOdometer: Int? {
        let text = lastServiceOdometerText.sanitizedIntInput()
        return text.isEmpty ? nil : Int(text)
    }

    private var selectedCatalogBrand: CarBrand? {
        isCustomBrand ? nil : CarCatalogService.shared.brand(named: brand)
    }

    private let maxPhotoBytes = 20 * 1024 * 1024

    var body: some View {
        NavigationStack {
            Form {
                vehicleTypeSection
                requiredSection
                if vehicleType == .motorcycle {
                    motorcycleSection
                }
                optionalSection
                purchaseInfoSection
                firstRemindersSection

                if showErrors && !validationErrors.isEmpty {
                    validationErrorsSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Araç Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: saveVehicle)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let item = newItem { loadPhotoItem(item) }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: .secondVehicle)
            }
        }
    }

    // MARK: - Vehicle Type Section
    private var vehicleTypeSection: some View {
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
                // Araç türü değişince motosiklet alanlarını sıfırla
                if newType == .car {
                    motorcycleType = nil
                    engineCCText = ""
                }
            }
        } header: {
            Text("Araç Türü")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Motorcycle Section
    private var motorcycleSection: some View {
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

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
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
                if let n = Int(engineCCText.sanitizedIntInput()), n > 0 {
                    HStack(spacing: 4) {
                        Spacer().frame(width: 24)
                        Text("\(n.formatted(.number.locale(Locale(identifier: "tr_TR")))) cc olarak kaydedilecek")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        } header: {
            Text("Motosiklet Bilgileri")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Required Section
    private var requiredSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Zorunlu Bilgiler")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.bottom, AppSpacing.xxs)

                formField(icon: "number", placeholder: "Plaka", text: $plate, keyboardType: .default)
                    .textInputAutocapitalization(.characters)

                VehicleCatalogSelectionField(
                    title: "Marka",
                    value: brand,
                    placeholder: "Marka seç",
                    systemImage: "car",
                    action: { showBrandPicker = true }
                )

                if isCustomBrand {
                    formField(icon: "pencil", placeholder: "Marka adı", text: $brand)
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
                    formField(icon: "pencil", placeholder: "Model adı", text: $model)
                }

                formField(icon: "calendar", placeholder: "Yıl", text: $yearText, keyboardType: .decimalPad, showNumberPreview: true)
                formField(icon: "gauge.with.needle", placeholder: "Güncel Km", text: $odometerText, keyboardType: .decimalPad, showNumberPreview: true, previewSuffix: " km")
            }

            Picker(selection: $fuelType) {
                ForEach(FuelType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Yakıt Tipi", systemImage: "fuelpump")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            Picker(selection: $transmissionType) {
                ForEach(TransmissionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Vites", systemImage: "gearshape")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            Picker(selection: $usageType) {
                ForEach(VehicleUsageType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Kullanım", systemImage: "person")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
        } header: {
            Text("Araç Bilgileri")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Optional Section
    private var optionalSection: some View {
        Section {
            formField(icon: "heart", placeholder: "Takma ad (isteğe bağlı)", text: $nickname)

            // Araç fotoğrafı
            VStack(spacing: AppSpacing.sm) {
                if let image = selectedPhotoImage {
                    // Seçili fotoğraf önizleme
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
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "camera")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(AppColors.backgroundSecondary)
                            )
                        Text(selectedPhotoImage == nil
                             ? "Araç fotoğrafı ekle (isteğe bağlı)"
                             : "Fotoğrafı Değiştir")
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .buttonStyle(.borderless)

                if let error = photoError {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.critical)
                }
            }
        } header: {
            Text("İsteğe Bağlı")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Purchase Info Section
    private var purchaseInfoSection: some View {
        Section {
            Toggle(isOn: $addPurchaseInfo) {
                Label("Satın Alma Bilgisi Ekle", systemImage: "cart")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.accentPrimary)

            if addPurchaseInfo {
                DatePicker(selection: $purchaseDate, displayedComponents: .date) {
                    Label("Satın Alma Tarihi", systemImage: "calendar")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "gauge.with.needle")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 24)
                        TextField("Satın Alma Km (isteğe bağlı)", text: $purchaseOdometerText)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                            .keyboardType(.decimalPad)
                    }
                    if let n = Int(purchaseOdometerText.sanitizedIntInput()), n > 0 {
                        HStack(spacing: 4) {
                            Spacer().frame(width: 24)
                            Text("\(n.formatted(.number.locale(Locale(identifier: "tr_TR")))) km olarak kaydedilecek")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "banknote")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 24)
                        TextField("Satın Alma Fiyatı - ₺ (isteğe bağlı)", text: $purchasePriceText)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                            .keyboardType(.decimalPad)
                    }
                    if let n = Int(purchasePriceText.sanitizedIntInput()), n > 0 {
                        HStack(spacing: 4) {
                            Spacer().frame(width: 24)
                            Text("\(n.formatted(.currency(code: "TRY").locale(Locale(identifier: "tr_TR")))) olarak kaydedilecek")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
            }
        } header: {
            Text("Satın Alma")
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - First Reminders Section
    private var firstRemindersSection: some View {
        Section {
            reminderToggle(
                icon: ReminderType.inspection.defaultIcon,
                title: "Muayene",
                subtitle: "Muayenenin yapıldığı tarihi gir",
                isOn: $addInspectionReminder,
                date: $inspectionDate,
                hasOdometer: false
            )

            reminderToggle(
                icon: ReminderType.trafficInsurance.defaultIcon,
                title: "Trafik Sigortası Bitiş Tarihi",
                subtitle: "Sigortanın biteceği tarihi gir",
                isOn: $addInsuranceReminder,
                date: $insuranceDate,
                hasOdometer: false
            )

            reminderToggle(
                icon: ReminderType.casco.defaultIcon,
                title: "Kasko Bitiş Tarihi",
                subtitle: "Kaskonun biteceği tarihi gir",
                isOn: $addCascoReminder,
                date: $cascoDate,
                hasOdometer: false
            )

            VStack(spacing: AppSpacing.xs) {
                reminderToggle(
                    icon: ReminderType.periodicService.defaultIcon,
                    title: "Son Bakım",
                    subtitle: "Son bakımın yapıldığı tarihi gir",
                    isOn: $addLastServiceReminder,
                    date: $lastServiceDate,
                    hasOdometer: true
                )

                if addLastServiceReminder {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack(spacing: AppSpacing.md) {
                            Spacer().frame(width: 24)
                            TextField("Km (isteğe bağlı)", text: $lastServiceOdometerText)
                                .keyboardType(.decimalPad)
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.small)
                                        .fill(AppColors.backgroundSecondary)
                                )
                        }
                        if let n = Int(lastServiceOdometerText.sanitizedIntInput()), n > 0 {
                            HStack(spacing: 4) {
                                Spacer().frame(width: 24)
                                Text("\(n.formatted(.number.locale(Locale(identifier: "tr_TR")))) km olarak kaydedilecek")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding(.leading, AppSpacing.xl)
                }
            }
        } header: {
            Text("İlk Önemli Tarihler (İsteğe Bağlı)")
        } footer: {
            Text("Bu tarihler için hatırlatıcı oluşturulur. 30 gün kala bildirim gönderilir. Daha sonra istediğin zaman düzenleyebilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Validation Errors Section
    private var validationErrorsSection: some View {
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
                .padding(.vertical, 2)
            }
        } header: {
            Text("Düzeltilmesi Gerekenler")
                .foregroundColor(AppColors.critical)
        }
        .listRowBackground(AppColors.criticalBackground)
    }

    // MARK: - Reminder Toggle Row
    private func reminderToggle(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        date: Binding<Date>,
        hasOdometer: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Toggle(isOn: isOn) {
                Label(title, systemImage: icon)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.accentPrimary)

            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .padding(.leading, AppSpacing.xl)
                .padding(.top, -AppSpacing.xxs)

            if isOn.wrappedValue {
                DatePicker(
                    "Tarih",
                    selection: date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(AppTypography.secondary)
                .padding(.leading, AppSpacing.xl)
            }
        }
    }

    // MARK: - Form Field
    private func formField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        showNumberPreview: Bool = false,
        previewSuffix: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 24)

                TextField(placeholder, text: text)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .keyboardType(keyboardType)
            }

            if showNumberPreview, let n = Int(text.wrappedValue.sanitizedIntInput()), n > 0 {
                HStack(spacing: 4) {
                    Spacer().frame(width: 24)
                    Text("\(n.formatted(.number.locale(Locale(identifier: "tr_TR"))))\(previewSuffix) olarak kaydedilecek")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.vertical, AppSpacing.xxs)
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

    // MARK: - Save Action
    private func saveVehicle() {
        let errors = validate()

        guard errors.isEmpty else {
            validationErrors = errors
            showErrors = true
            return
        }

        // Araç limit gate — yeni ekleme modunda kontrol
        let activeVehicles = (try? modelContext.fetch(FetchDescriptor<Vehicle>()))?.filter { $0.archivedAt == nil } ?? []
        if !paywallService.canAddVehicle(currentCount: activeVehicles.count) {
            showPaywall = true
            return
        }

        performSave()
    }

    private func validate() -> [String] {
        var errors: [String] = []

        let trimmedPlate = plate.trimmingCharacters(in: .whitespaces)
        if trimmedPlate.isEmpty {
            errors.append("Plaka zorunludur.")
        } else if trimmedPlate.count < 6 {
            errors.append("Plaka geçerli bir plaka numarası olmalıdır.")
        }

        if brand.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Marka zorunludur.")
        }

        if model.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Model zorunludur.")
        }

        if let year {
            let currentYear = Calendar.current.component(.year, from: Date())
            if year < 1900 || year > currentYear + 1 {
                errors.append("Yıl 1900 ile \(currentYear + 1) arasında olmalıdır.")
            }
        }

        if let odometer {
            if odometer < 0 {
                errors.append("Km sıfırdan küçük olamaz.")
            }
        } else {
            errors.append("Güncel km zorunludur.")
        }

        if addLastServiceReminder, let serviceKm = lastServiceOdometer, serviceKm < 0 {
            errors.append("Son bakım km sıfırdan küçük olamaz.")
        }

        return errors
    }

    private var purchaseOdometer: Int? {
        let text = purchaseOdometerText.sanitizedIntInput()
        return text.isEmpty ? nil : Int(text)
    }
    private var purchasePrice: Double? {
        let text = purchasePriceText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : Double(text)
    }

    private var engineCC: Int? {
        let text = engineCCText.sanitizedIntInput()
        return text.isEmpty ? nil : Int(text)
    }

    private func performSave() {
        // Fotoğraf kaydet
        var savedPhotoFileName: String?
        if let image = selectedPhotoImage {
            do {
                savedPhotoFileName = try VehiclePhotoStorageService.shared.savePhoto(image)
            } catch {
                photoError = error.localizedDescription
                return
            }
        }

        let vehicle = Vehicle(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            plate: plate.trimmingCharacters(in: .whitespaces).uppercased(),
            brand: brand.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            year: year,
            vehicleType: vehicleType,
            motorcycleType: vehicleType == .motorcycle ? motorcycleType : nil,
            engineCC: vehicleType == .motorcycle ? engineCC : nil,
            fuelType: fuelType,
            transmissionType: transmissionType,
            currentOdometer: odometer ?? 0,
            purchaseDate: addPurchaseInfo ? purchaseDate : nil,
            purchaseOdometer: addPurchaseInfo ? purchaseOdometer : nil,
            purchasePrice: addPurchaseInfo ? purchasePrice : nil,
            usageType: usageType,
            notes: "",
            photoFileName: savedPhotoFileName
        )
        modelContext.insert(vehicle)

        // İlk hatırlatıcıları oluştur
        createFirstReminders(for: vehicle.id)

        // Kaydet
        try? modelContext.save()

        // Başarı haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        Task { await NotificationRefreshService.refreshAll(context: modelContext) }
        dismiss()
    }

    private func createFirstReminders(for vehicleId: UUID) {
        if addInspectionReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .inspection,
                title: "Muayene",
                dueDate: inspectionDate,
                priority: .warning
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }

        if addInsuranceReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .trafficInsurance,
                title: "Trafik Sigortası",
                dueDate: insuranceDate,
                priority: .warning
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }

        if addCascoReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .casco,
                title: "Kasko",
                dueDate: cascoDate,
                priority: .warning
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }

        if addLastServiceReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .periodicService,
                title: "Periyodik Bakım",
                dueDate: Calendar.current.date(byAdding: .year, value: 1, to: lastServiceDate),
                dueOdometer: lastServiceOdometer.map { $0 + 10000 },
                priority: .info
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }
    }

    // MARK: - Photo Handling
    private func loadPhotoItem(_ item: PhotosPickerItem) {
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

enum VehiclePhotoSelectionError: LocalizedError {
    case unreadable
    case tooLarge
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "Fotoğraf okunamadı. Lütfen tekrar dene."
        case .tooLarge:
            return "Fotoğraf 20 MB'dan büyük olamaz. Daha küçük bir görsel seç."
        case .decodeFailed:
            return "Bu fotoğraf açılamadı. Lütfen JPG, PNG veya HEIC gibi geçerli bir görsel seç."
        }
    }
}

// MARK: - Preview
#Preview("Araç Ekleme Formu") {
    VehicleFormView()
}

#Preview("Araç Ekleme Formu — Dark Mode") {
    VehicleFormView()
}

// MARK: - Vehicle Form Wizard View (Karar 3.5)
// Onboarding sonrası ilk kez araç ekleme için 3 adımlı wizard.
// Mevcut `VehicleFormView` (6-section tek form) korunur — Garaj menüsünden
// ve test/dev ortamlarında eski form hâlâ kullanılır.
// Yalnızca onboarding sonrası ilk aracı eklerken wizard açılır.

struct VehicleFormWizardView: View {
    enum WizardStep: Int, CaseIterable, Identifiable {
        case identity = 0   // Tanımla
        case condition = 1  // Durumu
        case upcoming = 2   // Sıradaki işler

        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .identity: return "Tanımla"
            case .condition: return "Durumu"
            case .upcoming: return "Sıradaki İşler"
            }
        }

        /// Küçük başlık — üst ilerleme çubuğunda kullanılır.
        var shortTitle: String {
            switch self {
            case .identity: return "Tanımla"
            case .condition: return "Durumu"
            case .upcoming: return "Sıradaki İşler"
            }
        }
    }

    // MARK: Shared form state — VehicleFormView'daki state'lerin sade versiyonu
    @State private var currentStep: WizardStep = .identity
    @State private var errorMessage: String?
    @State private var isSaving = false

    // Step 1 — Identity
    @State private var vehicleType: VehicleType = .car
    @State private var plate = ""
    @State private var brand = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var showBrandPicker = false
    @State private var showModelPicker = false
    @State private var isCustomBrand = false
    @State private var isCustomModel = false

    // Step 2 — Condition
    @State private var odometerText = ""
    @State private var fuelType: FuelType = .gasoline
    @State private var transmissionType: TransmissionType = .automatic
    @State private var usageType: VehicleUsageType = .personal
    @State private var nickname = ""

    // Step 3 — Upcoming reminders (optional)
    @State private var addInspectionReminder = false
    @State private var inspectionDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()

    @State private var addInsuranceReminder = false
    @State private var insuranceDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var addMTVReminder = false
    private var mtvDefaultDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        var components = calendar.dateComponents([.year], from: now)
        components.month = currentMonth <= 6 ? 1 : 7
        components.day = 15
        return calendar.date(from: components) ?? now
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    // Not: paywallService environment object'i kullanılmıyor.
    // Bu wizard sadece ilk kez araç eklerken (vehicleCount=0) açılıyor;
    // paywall kontrolü burada gereksiz ve @EnvironmentObject erişimi
    // environment zincirinde sorun çıkarabiliyor.

// MARK: Validation per step
    private var canContinue: Bool {
        switch currentStep {
        case .identity:
            let trimmed = plate.trimmingCharacters(in: .whitespaces)
            // Plaka zorunlu ve en az 6 karakter olmalı
            return !trimmed.isEmpty && trimmed.count >= 6 && !isSaving
        case .condition, .upcoming:
            return !isSaving
        }
    }

    /// Plaka validasyonu — Türk plakaları en az 6 karakter (örn: 34 ABC 1234)
    private var plateValidationError: String? {
        let trimmed = plate.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil } // sessiz — boş durumda hata göstermeye gerek yok
        if trimmed.count < 6 { return "Plaka en az 6 karakter olmalı." }
        return nil
    }

    private var year: Int? {
        let trimmed = yearText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    private var odometer: Int? {
        let trimmed = odometerText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Int(trimmed)
    }

    private var hasAnyChosenReminder: Bool {
        addInspectionReminder || addInsuranceReminder || addMTVReminder
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator

                ScrollView {
                    Group {
                        switch currentStep {
                        case .identity: identityStep
                        case .condition: conditionStep
                        case .upcoming: upcomingStep
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
                }

                Divider()

                navigationButtons
            }
            .background(Color.appBackground)
            .navigationTitle(currentStep.shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
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
        }
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(WizardStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue
                          ? AppColors.accentPrimary
                          : AppColors.border)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Adım \(currentStep.rawValue + 1) / \(WizardStep.allCases.count): \(currentStep.shortTitle)")
    }

    // MARK: - Step 1 — Identity
    private var identityStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Aracını tanıyalım")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("Plaka ve model bilgisi yeterli. Geri kalanını istersen sonra ekleyebilirsin.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Gizlilik notu — plaka altında (Karar: plaka zorunlu alan olduğu için kısa güvence)
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.top, 2)
                Text("Plaka da dahil tüm verilerin cihazında saklanır. Arvia tarafından görülmez veya kullanılmaz.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.backgroundSecondary.opacity(0.35))
            )
            .accessibilityElement(children: .combine)

            // Araç Türü
            Picker(selection: $vehicleType) {
                ForEach(VehicleType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Araç Türü", systemImage: "steeringwheel")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .pickerStyle(.menu)

            wizardField(icon: "number", placeholder: "Plaka (zorunlu)", text: $plate)
                .textInputAutocapitalization(.characters)

            // Plaka validasyon mesajı (inline)
            if let plateError = plateValidationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)
                    Text(plateError)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.warning)
                    Spacer()
                }
                .transition(.opacity)
            }

            VehicleCatalogSelectionField(
                title: "Marka",
                value: brand,
                placeholder: "Marka seç",
                systemImage: "car",
                action: { showBrandPicker = true }
            )

            if isCustomBrand {
                wizardField(icon: "pencil", placeholder: "Marka adı", text: $brand)
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
                wizardField(icon: "pencil", placeholder: "Model adı", text: $model)
            }

            wizardField(icon: "calendar", placeholder: "Yıl (opsiyonel)", text: $yearText, keyboardType: .numberPad)
        }
        .padding(AppSpacing.md)
        .animation(.easeInOut(duration: 0.2), value: plateValidationError)
    }

    // MARK: - Step 2 — Condition
    private var conditionStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Aracının durumu")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("Tüm alanlar opsiyonel. Daha sonra Araç Detay'dan da güncelleyebilirsin.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            wizardField(icon: "gauge.with.needle", placeholder: "Güncel Km (opsiyonel)", text: $odometerText, keyboardType: .numberPad)

            Picker(selection: $fuelType) {
                ForEach(FuelType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Yakıt Tipi", systemImage: "fuelpump")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .pickerStyle(.menu)

            Picker(selection: $transmissionType) {
                ForEach(TransmissionType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Vites", systemImage: "gearshape")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .pickerStyle(.menu)

            Picker(selection: $usageType) {
                ForEach(VehicleUsageType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Label("Kullanım", systemImage: "person")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .pickerStyle(.menu)

            wizardField(icon: "heart", placeholder: "Takma ad (opsiyonel)", text: $nickname)
        }
        .padding(AppSpacing.md)
    }

    // MARK: - Step 3 — Upcoming
    private var upcomingStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Sıradaki işleri hazırlayalım mı?")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text("İstersen muayene, sigorta ve MTV için otomatik hatırlatıcı oluşturabiliriz. Yoksa hepsini atlayabilirsin.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            reminderToggle(
                icon: "checkmark.seal",
                title: "Muayene",
                subtitle: "Varsayılan 2 yıl sonra",
                isOn: $addInspectionReminder,
                date: $inspectionDate
            )

            reminderToggle(
                icon: "shield",
                title: "Trafik Sigortası",
                subtitle: "Varsayılan 1 yıl sonra",
                isOn: $addInsuranceReminder,
                date: $insuranceDate
            )

            reminderToggle(
                icon: "doc.text",
                title: "MTV",
                subtitle: "Yılın 1. veya 2. yarısı (otomatik)",
                isOn: $addMTVReminder,
                date: .constant(mtvDefaultDate),
                disabled: true
            )
        }
        .padding(AppSpacing.md)
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        VStack(spacing: AppSpacing.xs) {
            // Hata mesajı
            if let errorMessage {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppColors.critical)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.critical)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .fill(AppColors.criticalBackground)
                )
                .padding(.horizontal, AppSpacing.screenMarginH)
            }

            HStack(spacing: AppSpacing.sm) {
                if currentStep != .identity {
                    Button("Geri") {
                        withAnimation { currentStep = WizardStep(rawValue: currentStep.rawValue - 1) ?? .identity }
                    }
                    .buttonStyle(.secondary)
                    .disabled(isSaving)
                }

                if currentStep != .upcoming {
                    Button("Devam") {
                        withAnimation { currentStep = WizardStep(rawValue: currentStep.rawValue + 1) ?? .upcoming }
                    }
                    .buttonStyle(.primary)
                    .disabled(!canContinue)
                } else {
                    Button(hasAnyChosenReminder ? "Aracı Ekle" : "Atla ve Ekle") {
                        saveVehicleFromWizard()
                    }
                    .buttonStyle(.primary)
                    .disabled(isSaving)
                }
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Wizard Helpers

    private var selectedCatalogBrand: CarBrand? {
        isCustomBrand ? nil : CarCatalogService.shared.brand(named: brand)
    }

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

    private func wizardField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboardType)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.backgroundSecondary.opacity(0.5))
        )
    }

    private func reminderToggle(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        date: Binding<Date>,
        disabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppColors.accentPrimary.opacity(0.1))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if disabled {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                } else {
                    Toggle("", isOn: isOn)
                        .labelsHidden()
                        .tint(AppColors.accentPrimary)
                        .disabled(disabled)
                }
            }

            if !disabled && isOn.wrappedValue {
                DatePicker(
                    "Tarih",
                    selection: date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(AppTypography.secondary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.backgroundSecondary.opacity(0.5))
        )
    }

    // MARK: - Save Action
    private func saveVehicleFromWizard() {
        errorMessage = nil

        let trimmedPlate = plate.trimmingCharacters(in: .whitespaces)
        guard !trimmedPlate.isEmpty else {
            errorMessage = "Plaka zorunludur."
            return
        }
        guard trimmedPlate.count >= 6 else {
            errorMessage = "Plaka en az 6 karakter olmalı."
            return
        }

        // Re-entrance guard
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        // Not: Paywall kontrolü YOK. Bu wizard sadece onboarding sonrası
        // ilk kez araç eklerken açılır (vehicleCount=0 garantili), yani
        // ücretsiz planda 1 araç limiti zaten geçerli. İkinci aracı
        // kullanıcı zaten Garaj toolbar'dan eski VehicleFormView ile eklemeli.

        let vehicle = Vehicle(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            plate: trimmedPlate.uppercased(),
            brand: brand.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            year: year,
            vehicleType: vehicleType,
            fuelType: fuelType,
            transmissionType: transmissionType,
            currentOdometer: odometer ?? 0,
            usageType: usageType,
            notes: ""
        )

        do {
            modelContext.insert(vehicle)

            // Hatırlatıcılar (sadece seçili olanlar)
            if addInspectionReminder {
                let r = Reminder(
                    vehicleId: vehicle.id,
                    type: .inspection,
                    title: "Muayene",
                    dueDate: inspectionDate,
                    priority: .warning
                )
                modelContext.insert(r)
                Task { await NotificationService.shared.scheduleReminder(r) }
            }
            if addInsuranceReminder {
                let r = Reminder(
                    vehicleId: vehicle.id,
                    type: .trafficInsurance,
                    title: "Trafik Sigortası",
                    dueDate: insuranceDate,
                    priority: .warning
                )
                modelContext.insert(r)
                Task { await NotificationService.shared.scheduleReminder(r) }
            }
            if addMTVReminder {
                let r = Reminder(
                    vehicleId: vehicle.id,
                    type: .mtvFirst,
                    title: "MTV 1. Taksit",
                    dueDate: mtvDefaultDate,
                    priority: .info
                )
                modelContext.insert(r)
                Task { await NotificationService.shared.scheduleReminder(r) }
            }

            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await NotificationRefreshService.refreshAll(context: modelContext) }
            dismiss()
        } catch {
            // Hata olursa eklenen vehicle'ı context'ten geri al
            modelContext.delete(vehicle)
            try? modelContext.save()
            errorMessage = "Araç kaydedilemedi: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Wizard Preview
#Preview("Araç Ekleme Sihirbazı") {
    VehicleFormWizardView()
        .modelContainer(MockDataProvider.emptyPreviewContainer)
}

#Preview("Araç Ekleme Sihirbazı — Dark") {
    VehicleFormWizardView()
        .modelContainer(MockDataProvider.emptyPreviewContainer)
}
