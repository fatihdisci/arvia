import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Vehicle Wizard Draft
// 3 adımlı araç ekleme wizard'ı için tek state modeli.
// Karar 3.5: Tanımla → Durumu → Sıradaki işler.
// Tüm step'ler aynı draft üzerinde çalışır; save tek noktada (Step 3) olur.

@Observable
final class VehicleWizardDraft {
    // Step 1 — Tanımla (zorunlu)
    var vehicleType: VehicleType = .car
    var plate: String = ""
    var brand: String = ""
    var model: String = ""
    var yearText: String = ""

    // Step 2 — Durumu (opsiyonel)
    var odometerText: String = ""
    var fuelType: FuelType = .gasoline
    var usageType: VehicleUsageType = .personal
    var transmissionType: TransmissionType = .automatic
    var motorcycleType: MotorcycleType?
    var engineCCText: String = ""
    var nickname: String = ""
    var selectedPhotoItem: PhotosPickerItem?
    var selectedPhotoImage: UIImage?
    var photoError: String?

    // Step 2 — Satın alma (opsiyonel)
    var addPurchaseInfo: Bool = false
    var purchaseDate: Date = Date()
    var purchaseOdometerText: String = ""
    var purchasePriceText: String = ""

    // Step 3 — Sıradaki işler (3 hazır hatırlatıcı)
    var addInspectionReminder: Bool = false
    var inspectionDate: Date = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()

    var addInsuranceReminder: Bool = false
    var insuranceDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    var addMTVReminder: Bool = false
    /// MTV taksit ayı: Ocak (1) veya Temmuz (7). Kullanıcı seçer.
    var mtvInstallmentMonth: Int = Calendar.current.component(.month, from: Date()) == 7 ? 7 : 1

    // MARK: - Computed helpers

    var year: Int? { Int(yearText.sanitizedIntInput()) }
    var odometer: Int? { Int(odometerText.sanitizedIntInput()) }
    var engineCC: Int? {
        let text = engineCCText.sanitizedIntInput()
        return text.isEmpty ? nil : Int(text)
    }
    var purchaseOdometer: Int? {
        let text = purchaseOdometerText.sanitizedIntInput()
        return text.isEmpty ? nil : Int(text)
    }
    var purchasePrice: Double? {
        let text = purchasePriceText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : Double(text)
    }

    var selectedCatalogBrand: CarBrand? {
        CarCatalogService.shared.brand(named: brand)
    }

    // MARK: - Step gating

    /// Step 1 → Step 2 geçişi için gerekli minimum alanlar.
    func canProceedFromIdentify() -> Bool {
        let trimmedPlate = plate.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        return trimmedPlate.count >= 6 && !trimmedBrand.isEmpty && !trimmedModel.isEmpty
    }

    /// Step 2 → Step 3 her zaman serbest (tüm alanlar opsiyonel).
    func canProceedFromStatus() -> Bool {
        if let odometer, odometer < 0 { return false }
        return true
    }

    /// Step 3'te save için final validation.
    func validateForSave() -> [String] {
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
        if let odometer, odometer < 0 {
            errors.append("Km sıfırdan küçük olamaz.")
        }
        return errors
    }
}

// MARK: - Vehicle Wizard View (Container)
// 3 step'li NavigationStack. Üstte step indicator, altta İleri/Geri/Kaydet bar.

/// Tüm focusable alanlar — klavye yönetimi ve otomatik scroll için.
enum WizardField: Hashable {
    case plate, year
    case odometer, engineCC, nickname
    case purchaseOdometer, purchasePrice
}

struct VehicleWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    @State private var draft = VehicleWizardDraft()
    @State private var currentStep: Int = 1
    @State private var showBrandPicker: Bool = false
    @State private var showModelPicker: Bool = false
    @State private var showErrors: Bool = false
    @State private var showPaywall: Bool = false

    /// Aktif TextField. Picker seçimleri ve step geçişlerinde nil yapılır
    /// (klavye kapanır). ScrollViewReader onChange ile aktif field'a scroll eder.
    @FocusState private var focusedField: WizardField?

    private let totalSteps = 3
    private let maxPhotoBytes = 20 * 1024 * 1024

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Üst — step indicator
                WizardStepIndicator(current: currentStep, total: totalSteps, title: stepTitle(for: currentStep))
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)

                // Orta — aktif step içeriği (ScrollViewReader extracted)
                scrollableStepContent

                // Alt — navigation bar (İleri / Geri / Kaydet)
                WizardNavBar(
                    currentStep: $currentStep,
                    totalSteps: totalSteps,
                    canGoBack: currentStep > 1,
                    canGoForward: canGoForward,
                    onBack: {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.25)) { currentStep -= 1 }
                    },
                    onForward: {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
                    },
                    onSave: saveVehicle
                )
            }
            .background(Color.appBackground)
            .navigationTitle("Araç Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                // Klavyenin üstünde "Kapat" — hızlı erişim
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Kapat") { focusedField = nil }
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .sheet(isPresented: $showBrandPicker) {
                CarBrandPickerSheet(service: CarCatalogService.shared, selectedBrand: draft.brand) { selectedBrand in
                    if let selectedBrand {
                        draft.brand = selectedBrand.displayName
                        draft.model = ""
                    } else {
                        draft.brand = ""
                        draft.model = ""
                    }
                    // Picker seçildi → klavye kapansın
                    focusedField = nil
                }
            }
            .sheet(isPresented: $showModelPicker) {
                if let catalogBrand = draft.selectedCatalogBrand {
                    CarModelPickerSheet(service: CarCatalogService.shared, brand: catalogBrand, selectedModel: draft.model) { selectedModel in
                        draft.model = selectedModel?.displayName ?? ""
                    }
                    // Sheet kapandığında klavye kapansın
                    .onDisappear { focusedField = nil }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: .secondVehicle)
            }
            .onChange(of: draft.selectedPhotoItem) { _, newItem in
                if let item = newItem { loadPhotoItem(item) }
            }
        }
    }

    /// Orta alan — step içeriği ScrollViewReader içinde. Aktif TextField'a
    /// otomatik scroll; klavye açıkken alan klavyenin altında kalmaz.
    @ViewBuilder
    private var scrollableStepContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                activeStepView
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.bottom, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground)
            .onChange(of: focusedField) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .bottom)
                }
            }
            .onChange(of: currentStep) { _, _ in
                // Step değişince klavyeyi kapat (alan kalmayabilir).
                focusedField = nil
            }
        }
    }

    /// Aktif step'in view içeriği — extracted (type-check hızı için).
    @ViewBuilder
    private var activeStepView: some View {
        switch currentStep {
        case 1:
            WizardIdentifyStep(
                draft: draft,
                focusedField: $focusedField,
                showBrandPicker: $showBrandPicker,
                showModelPicker: $showModelPicker
            )
        case 2:
            WizardStatusStep(draft: draft, focusedField: $focusedField)
        case 3:
            WizardNextStepsStep(draft: draft)
        default:
            EmptyView()
        }
    }

    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "Tanımla"
        case 2: return "Durumu"
        case 3: return "Sıradaki işler"
        default: return ""
        }
    }

    private var canGoForward: Bool {
        switch currentStep {
        case 1: return draft.canProceedFromIdentify()
        case 2: return draft.canProceedFromStatus()
        default: return false
        }
    }

    // MARK: - Save

    private func saveVehicle() {
        let errors = draft.validateForSave()
        guard errors.isEmpty else {
            // Validation error varsa kullanıcıyı Step 1'e geri gönder.
            showErrors = true
            currentStep = 1
            return
        }

        // Paywall gate.
        let activeVehicles = (try? modelContext.fetch(FetchDescriptor<Vehicle>()))?.filter { $0.archivedAt == nil } ?? []
        if !paywallService.canAddVehicle(currentCount: activeVehicles.count) {
            showPaywall = true
            return
        }

        performSave()
    }

    private func performSave() {
        // Fotoğraf kaydet.
        var savedPhotoFileName: String?
        if let image = draft.selectedPhotoImage {
            do {
                savedPhotoFileName = try VehiclePhotoStorageService.shared.savePhoto(image)
            } catch {
                draft.photoError = error.localizedDescription
                return
            }
        }

        // Vehicle oluştur.
        let vehicle = Vehicle(
            nickname: draft.nickname.trimmingCharacters(in: .whitespaces),
            plate: draft.plate.trimmingCharacters(in: .whitespaces).uppercased(),
            brand: draft.brand.trimmingCharacters(in: .whitespaces),
            model: draft.model.trimmingCharacters(in: .whitespaces),
            year: draft.year,
            vehicleType: draft.vehicleType,
            motorcycleType: draft.vehicleType == .motorcycle ? draft.motorcycleType : nil,
            engineCC: draft.vehicleType == .motorcycle ? draft.engineCC : nil,
            fuelType: draft.fuelType,
            transmissionType: draft.transmissionType,
            currentOdometer: draft.odometer ?? 0,
            purchaseDate: draft.addPurchaseInfo ? draft.purchaseDate : nil,
            purchaseOdometer: draft.addPurchaseInfo ? draft.purchaseOdometer : nil,
            purchasePrice: draft.addPurchaseInfo ? draft.purchasePrice : nil,
            usageType: draft.usageType,
            notes: "",
            photoFileName: savedPhotoFileName
        )
        modelContext.insert(vehicle)

        // Step 3 — seçilen hatırlatıcıları oluştur.
        createStepThreeReminders(for: vehicle.id)

        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        Task { await NotificationRefreshService.refreshAll(context: modelContext) }
        dismiss()
    }

    private func createStepThreeReminders(for vehicleId: UUID) {
        if draft.addInspectionReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .inspection,
                title: "Muayene",
                dueDate: draft.inspectionDate,
                priority: .warning
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }

        if draft.addInsuranceReminder {
            let r = Reminder(
                vehicleId: vehicleId,
                type: .trafficInsurance,
                title: "Trafik Sigortası",
                dueDate: draft.insuranceDate,
                priority: .warning
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }

        if draft.addMTVReminder {
            // MTV taksit ayı seçildiyse — yılın ilgili taksit dönemi.
            let type: ReminderType = draft.mtvInstallmentMonth == 1 ? .mtvFirst : .mtvSecond
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year], from: Date())
            components.month = draft.mtvInstallmentMonth
            components.day = 15
            let dueDate = calendar.date(from: components) ?? Date()
            let title = draft.mtvInstallmentMonth == 1 ? "MTV 1. Taksit" : "MTV 2. Taksit"

            let r = Reminder(
                vehicleId: vehicleId,
                type: type,
                title: title,
                dueDate: dueDate,
                priority: .info
            )
            modelContext.insert(r)
            Task { await NotificationService.shared.scheduleReminder(r) }
        }
    }

    // MARK: - Photo handling

    private func loadPhotoItem(_ item: PhotosPickerItem) {
        draft.photoError = nil
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
                    draft.selectedPhotoItem = nil
                    draft.selectedPhotoImage = image
                }
            } catch {
                await MainActor.run {
                    draft.selectedPhotoItem = nil
                    draft.selectedPhotoImage = nil
                    draft.photoError = (error as? LocalizedError)?.errorDescription ?? "Fotoğraf okunamadı."
                }
            }
        }
    }
}

// MARK: - Step Indicator

struct WizardStepIndicator: View {
    let current: Int
    let total: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(1...total, id: \.self) { step in
                    Capsule()
                        .fill(step <= current ? AppColors.accentPrimary : AppColors.border)
                        .frame(height: 3)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Adım \(current) / \(total)")
                    .font(AppTypography.labelCaps)
                    .tracking(0.5)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

// MARK: - Step 1 — Tanımla

struct WizardIdentifyStep: View {
    let draft: VehicleWizardDraft
    @FocusState.Binding var focusedField: WizardField?
    @Binding var showBrandPicker: Bool
    @Binding var showModelPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            header

            VStack(spacing: AppSpacing.md) {
                // Araç türü
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    sectionLabel("Araç Türü")
                    Picker("Araç Türü", selection: Binding(
                        get: { draft.vehicleType },
                        set: { draft.vehicleType = $0 }
                    )) {
                        ForEach(VehicleType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Plaka
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    sectionLabel("Plaka")
                    TextField("34 ABC 123", text: Binding(
                        get: { draft.plate },
                        set: { draft.plate = $0 }
                    ))
                    .id(WizardField.plate)
                    .focused($focusedField, equals: .plate)
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .year }
                    .font(AppTypography.plateDisplay)
                    .tracking(3)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.input)
                            .fill(AppColors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.input)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }

                // Marka
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    sectionLabel("Marka")
                    Button {
                        focusedField = nil
                        showBrandPicker = true
                    } label: {
                        HStack {
                            Text(draft.brand.isEmpty ? "Marka seç" : draft.brand)
                                .foregroundColor(draft.brand.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.input)
                                .fill(AppColors.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.input)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Model
                if !draft.brand.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        sectionLabel("Model")
                        Button {
                            focusedField = nil
                            showModelPicker = true
                        } label: {
                            HStack {
                                Text(draft.model.isEmpty ? "Model seç" : draft.model)
                                    .foregroundColor(draft.model.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(AppSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.input)
                                    .fill(AppColors.backgroundSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.input)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Yıl
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    sectionLabel("Model Yılı")
                    TextField("Örn. 2022", text: Binding(
                        get: { draft.yearText },
                        set: { draft.yearText = $0 }
                    ))
                    .id(WizardField.year)
                    .focused($focusedField, equals: .year)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.input)
                            .fill(AppColors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.input)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Aracını tanıyalım")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
            Text("Plaka, marka ve model bilgileri ile başlayalım. Diğer bilgileri sonra ekleyebilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.labelCaps)
            .tracking(0.5)
            .foregroundColor(AppColors.textTertiary)
    }
}

// MARK: - Step 2 — Durumu

struct WizardStatusStep: View {
    let draft: VehicleWizardDraft
    @FocusState.Binding var focusedField: WizardField?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            header

            VStack(spacing: AppSpacing.md) {
                // Km
                vField(label: "Güncel Km") {
                    TextField("Örn. 45000", text: Binding(
                        get: { draft.odometerText },
                        set: { draft.odometerText = $0 }
                    ))
                    .id(WizardField.odometer)
                    .focused($focusedField, equals: .odometer)
                    .keyboardType(.numberPad)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .engineCC }
                }

                // Motosiklet alanları (gerekirse)
                if draft.vehicleType == .motorcycle {
                    vField(label: "Motor Tipi") {
                        Picker("Motor Tipi", selection: Binding(
                            get: { draft.motorcycleType ?? .naked },
                            set: { draft.motorcycleType = $0 }
                        )) {
                            ForEach(MotorcycleType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    vField(label: "Motor Hacmi (cc)") {
                        TextField("Örn. 650", text: Binding(
                            get: { draft.engineCCText },
                            set: { draft.engineCCText = $0 }
                        ))
                        .id(WizardField.engineCC)
                        .focused($focusedField, equals: .engineCC)
                        .keyboardType(.numberPad)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .nickname }
                    }
                }

                // Yakıt
                vField(label: "Yakıt Tipi") {
                    Picker("Yakıt Tipi", selection: Binding(
                        get: { draft.fuelType },
                        set: { draft.fuelType = $0 }
                    )) {
                        ForEach(FuelType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Vites
                vField(label: "Vites") {
                    Picker("Vites", selection: Binding(
                        get: { draft.transmissionType },
                        set: { draft.transmissionType = $0 }
                    )) {
                        ForEach(TransmissionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Kullanım
                vField(label: "Kullanım") {
                    Picker("Kullanım", selection: Binding(
                        get: { draft.usageType },
                        set: { draft.usageType = $0 }
                    )) {
                        ForEach(VehicleUsageType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Takma ad (opsiyonel)
                vField(label: "Takma Ad (opsiyonel)") {
                    TextField("Örn. Aile Aracı", text: Binding(
                        get: { draft.nickname },
                        set: { draft.nickname = $0 }
                    ))
                    .id(WizardField.nickname)
                    .focused($focusedField, equals: .nickname)
                }

                // Fotoğraf
                vField(label: "Fotoğraf (opsiyonel)") {
                    photoPicker
                }

                // Satın alma bilgisi
                purchaseSection
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Aracının şu anki durumu")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
            Text("Tüm alanlar isteğe bağlı. Sadece bildiğin bilgileri girersen yeterli.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: Binding(
            get: { draft.selectedPhotoItem },
            set: { draft.selectedPhotoItem = $0 }
        ), matching: .images) {
            HStack(spacing: AppSpacing.sm) {
                if let image = draft.selectedPhotoImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                    Text("Fotoğraf seçildi")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.body)
                        .foregroundColor(AppColors.accentPrimary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle().fill(AppColors.accentPrimary.opacity(0.12))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fotoğraf ekle")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Garajını kişiselleştirmek için")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.input)
                    .fill(AppColors.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.input)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Toggle(isOn: Binding(
                get: { draft.addPurchaseInfo },
                set: { draft.addPurchaseInfo = $0 }
            )) {
                Text("Satın alma bilgisi ekle")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.accentPrimary)

            if draft.addPurchaseInfo {
                vField(label: "Satın Alma Tarihi") {
                    DatePicker(
                        "Tarih",
                        selection: Binding(
                            get: { draft.purchaseDate },
                            set: { draft.purchaseDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                vField(label: "Satın Alma Km (opsiyonel)") {
                    TextField("Örn. 0", text: Binding(
                        get: { draft.purchaseOdometerText },
                        set: { draft.purchaseOdometerText = $0 }
                    ))
                    .id(WizardField.purchaseOdometer)
                    .focused($focusedField, equals: .purchaseOdometer)
                    .keyboardType(.numberPad)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .purchasePrice }
                }

                vField(label: "Satın Alma Fiyatı (₺, opsiyonel)") {
                    TextField("Örn. 850000", text: Binding(
                        get: { draft.purchasePriceText },
                        set: { draft.purchasePriceText = $0 }
                    ))
                    .id(WizardField.purchasePrice)
                    .focused($focusedField, equals: .purchasePrice)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func vField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppTypography.labelCaps)
                .tracking(0.5)
                .foregroundColor(AppColors.textTertiary)
            content()
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.input)
                        .fill(AppColors.backgroundSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.input)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Step 3 — Sıradaki işler

struct WizardNextStepsStep: View {
    let draft: VehicleWizardDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            header

            VStack(spacing: AppSpacing.md) {
                // 3 hazır hatırlatıcı kartı
                reminderCard(
                    icon: ReminderType.inspection.defaultIcon,
                    title: "Muayene",
                    subtitle: "Muayenenin yapıldığı tarihi gir. Bitişine 30 gün kala hatırlatır.",
                    isOn: Binding(get: { draft.addInspectionReminder }, set: { draft.addInspectionReminder = $0 }),
                    date: Binding(get: { draft.inspectionDate }, set: { draft.inspectionDate = $0 }),
                    accent: AppColors.accentPrimary
                )

                reminderCard(
                    icon: ReminderType.trafficInsurance.defaultIcon,
                    title: "Trafik Sigortası",
                    subtitle: "Sigortanın yenilenmesi gereken tarihi gir.",
                    isOn: Binding(get: { draft.addInsuranceReminder }, set: { draft.addInsuranceReminder = $0 }),
                    date: Binding(get: { draft.insuranceDate }, set: { draft.insuranceDate = $0 }),
                    accent: AppColors.accentSecondary
                )

                mtvCard
            }

            Text("İstediğin hatırlatıcıları seç. Geri kalanını sonra Yapılacaklar'dan ekleyebilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, AppSpacing.sm)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Sıradaki işler")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
            Text("Yaklaşan önemli tarihler için hatırlatıcı oluşturalım. Tümü isteğe bağlı.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mtvCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Toggle(isOn: Binding(get: { draft.addMTVReminder }, set: { draft.addMTVReminder = $0 })) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "creditcard.fill")
                        .font(.body)
                        .foregroundColor(AppColors.warning)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppColors.warning.opacity(0.12)))
                    Text("MTV (Motorlu Taşıtlar Vergisi)")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .tint(AppColors.accentPrimary)

            if draft.addMTVReminder {
                Text("Taksit dönemi seç")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.leading, AppSpacing.xl)
                Picker("Taksit", selection: Binding(
                    get: { draft.mtvInstallmentMonth },
                    set: { draft.mtvInstallmentMonth = $0 }
                )) {
                    Text("Ocak (1. taksit)").tag(1)
                    Text("Temmuz (2. taksit)").tag(7)
                }
                .pickerStyle(.segmented)
                .padding(.leading, AppSpacing.xl)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
    }

    @ViewBuilder
    private func reminderCard(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        date: Binding<Date>,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Toggle(isOn: isOn) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(accent)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(accent.opacity(0.12)))
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .tint(AppColors.accentPrimary)

            if isOn.wrappedValue {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.leading, AppSpacing.xl)
                DatePicker(
                    "Tarih",
                    selection: date,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.leading, AppSpacing.xl)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
    }
}

// MARK: - Navigation Bar (alt)

struct WizardNavBar: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if canGoBack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                        Text("Geri")
                    }
                }
                .buttonStyle(.secondary)
                .frame(maxWidth: 120)
            }

            if currentStep < totalSteps {
                Button(action: onForward) {
                    HStack(spacing: 4) {
                        Text("İleri")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.primary)
                .disabled(!canGoForward)
            } else {
                Button(action: onSave) {
                    HStack(spacing: 4) {
                        Text("Kaydet")
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.primary)
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.md)
        .background(
            Color.appBackground
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(AppColors.border),
                    alignment: .top
                )
        )
    }
}

// MARK: - AppRadius alias

extension AppRadius {
    /// Form input alanları için orta radius. Anayasadaki 8px medium.
    static let input: CGFloat = AppRadius.medium
}