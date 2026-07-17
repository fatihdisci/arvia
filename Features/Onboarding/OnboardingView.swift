import SwiftUI
import SwiftData

// MARK: - Onboarding (1.1.0)
// Amaç-odaklı, 6 adımlı akış. Premium, sakin, Apple-native. Emoji yok,
// mavi-mor gradient yok, uzun tanıtım slaytı yok.
//
// Adımlar:
//   0. Değer önerisi
//   1. Kullanıcının önceliği (tek seçim → primary_goal)
//   2. İlk araç (marka/model/yıl zorunlu; plaka/km opsiyonel)
//   3. İlk değer anı (amaca göre: hatırlatma / masraf / belge — geçilebilir)
//   4. Bildirim izni (önce neden, sonra sistem izni; ret akışı bloke etmez)
//   5. Kişisel sonuç → uygulamaya geçiş
//
// Akış durumu AppStorage'da tutulur; uygulama kapanıp açılırsa kaldığı adımdan
// devam eder. Oluşturulan araç SwiftData'da yaşadığı için (adım 2 sonrası),
// yarım kalan akışta veri kaybı olmaz.

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(OnboardingConstants.completedKey) private var onboardingCompleted = false
    @AppStorage(OnboardingConstants.versionKey) private var onboardingVersion = 0
    @AppStorage(OnboardingConstants.goalKey) private var storedGoalRaw = ""
    @AppStorage(OnboardingConstants.stepKey) private var stepIndex = 0

    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var allReminders: [Reminder]
    @Query private var allExpenses: [Expense]
    @Query private var allDocuments: [VehicleDocument]

    // Araç formu (adım 2)
    @State private var brand = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var plate = ""
    @State private var kmText = ""
    @State private var vehicleError: String?

    // İlk değer anı (adım 3)
    @State private var firstValueSheet: FirstValueSheet?
    @State private var firstValueBaseline: Int?

    // Bildirim (adım 4)
    @State private var notificationInFlight = false

    @State private var didLogStart = false

    private let totalSteps = 6
    private let currentYear = Calendar.current.component(.year, from: Date())

    private enum FirstValueSheet: String, Identifiable {
        case reminder, expense, document
        var id: String { rawValue }
    }

    private var goal: OnboardingGoal? {
        OnboardingGoal(rawValue: storedGoalRaw)
    }

    private var activeVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt == nil }
    }

    /// Onboarding boyunca "aktif" araç — yeni oluşturulan ya da (CloudKit geri
    /// yüklemesinde) mevcut en son araç. createdVehicleId'ye gerek bırakmaz,
    /// böylece yarım kalan akış relaunch'ta doğru aracı gösterir.
    private var onboardingVehicle: Vehicle? {
        activeVehicles.last
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.top, AppSpacing.md)

            ScrollView {
                stepContent
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.top, AppSpacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ctaBar
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.bottom, AppSpacing.lg)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            if !didLogStart, stepIndex == 0 {
                AnalyticsService.shared.log(.onboardingStarted)
                didLogStart = true
            }
        }
        .sheet(item: $firstValueSheet, onDismiss: handleFirstValueDismiss) { sheet in
            firstValueForm(for: sheet)
        }
    }

    // MARK: - Progress
    private var progressBar: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= stepIndex ? AppColors.accentPrimary : AppColors.textTertiary.opacity(0.25))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: stepIndex)
        .accessibilityHidden(true)
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch stepIndex {
        case 0: valuePropStep
        case 1: goalStep
        case 2: vehicleStep
        case 3: firstValueStep
        case 4: notificationStep
        default: resultStep
        }
    }

    // MARK: - Step 0 — Değer önerisi
    private var valuePropStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            stepIcon("car.fill", color: AppColors.accentPrimary)
            stepHeadline(
                title: "Aracın için tek merkez.",
                subtitle: "Bakımını, masraflarını ve önemli tarihlerini tek yerde takip et. Her şey cihazında, senin kontrolünde."
            )
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                valueRow(icon: "bell.badge", text: "Muayene, sigorta ve bakım tarihlerini kaçırma")
                valueRow(icon: "turkishlirasign.circle", text: "Masraflarını kaydet, nereye gittiğini gör")
                valueRow(icon: "doc.text", text: "Belgelerini düzenli ve elinin altında tut")
            }
            .padding(.top, AppSpacing.sm)
        }
    }

    private func valueRow(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 28)
            Text(text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Step 1 — Öncelik
    private var goalStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            stepHeadline(
                title: "Arvia'yı en çok ne için kullanmak istiyorsun?",
                subtitle: "Sana en uygun başlangıcı hazırlayalım. İstediğin zaman değiştirebilirsin."
            )
            VStack(spacing: AppSpacing.sm) {
                ForEach(OnboardingGoal.allCases) { option in
                    goalRow(option)
                }
            }
        }
    }

    private func goalRow(_ option: OnboardingGoal) -> some View {
        let isSelected = goal == option
        return Button {
            storedGoalRaw = option.rawValue
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: option.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.accentPrimary : AppColors.textSecondary)
                    .frame(width: 32)
                Text(option.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.accentPrimary : AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(isSelected ? AppColors.accentPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Step 2 — Araç
    @ViewBuilder
    private var vehicleStep: some View {
        if let existing = onboardingVehicle {
            // CloudKit geri yüklemesi / geri gelme senaryosu: araç zaten var.
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                stepIcon("checkmark.circle.fill", color: AppColors.success)
                stepHeadline(
                    title: "Aracın zaten hazır",
                    subtitle: "\(existing.fullName.isEmpty ? "Aracın" : existing.fullName) dosyanda görünüyor. Devam edelim."
                )
            }
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                stepHeadline(
                    title: "İlk aracını ekleyelim",
                    subtitle: "Sadece birkaç bilgi yeterli. Kalanını sonra tamamlayabilirsin."
                )
                VStack(spacing: AppSpacing.md) {
                    onboardingField(title: "Marka", text: $brand, placeholder: "Örn. Toyota", required: true)
                    onboardingField(title: "Model", text: $model, placeholder: "Örn. Corolla", required: true)
                    onboardingField(title: "Yıl", text: $yearText, placeholder: "Örn. \(currentYear)", required: true, keyboard: .numberPad)
                    onboardingField(title: "Plaka", text: $plate, placeholder: "Opsiyonel", required: false, autocapitalize: true)
                    onboardingField(title: "Kilometre", text: $kmText, placeholder: "Opsiyonel", required: false, keyboard: .numberPad)
                }
                if let vehicleError {
                    Text(vehicleError)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.critical)
                }
            }
            .onAppear {
                AnalyticsService.shared.log(.onboardingVehicleStepStarted)
            }
        }
    }

    private func onboardingField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        required: Bool,
        keyboard: UIKeyboardType = .default,
        autocapitalize: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                if !required {
                    Text("· opsiyonel")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            TextField(placeholder, text: text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalize ? .characters : .sentences)
                .autocorrectionDisabled(autocapitalize)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .fill(Color.appSurface)
                )
        }
    }

    // MARK: - Step 3 — İlk değer anı
    private var firstValueStep: some View {
        let g = goal ?? .importantDates
        return VStack(alignment: .leading, spacing: AppSpacing.lg) {
            stepIcon(g.icon, color: AppColors.accentPrimary)
            stepHeadline(title: firstValueTitle(for: g), subtitle: firstValueSubtitle(for: g))
            Button {
                firstValueBaseline = firstValueCount(for: g)
                firstValueSheet = firstValueSheetType(for: g)
            } label: {
                Label(firstValueCTA(for: g), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
            .padding(.top, AppSpacing.sm)
        }
    }

    private func firstValueTitle(for g: OnboardingGoal) -> String {
        switch g {
        case .maintenance: return "İlk bakım hatırlatmanı kur"
        case .importantDates: return "İlk önemli tarihini ekle"
        case .expenses: return "İlk masrafını kaydet"
        case .documents: return "İlk belgeni ekle"
        }
    }

    private func firstValueSubtitle(for g: OnboardingGoal) -> String {
        switch g {
        case .maintenance: return "Periyodik bakım tarihini ekle; zamanı gelince sana hatırlatalım."
        case .importantDates: return "Muayene, sigorta veya kasko tarihini ekle; yaklaşınca haber verelim."
        case .expenses: return "Bir masraf ekle; aylık ve kategori bazlı özetin oluşmaya başlasın."
        case .documents: return "Ruhsat, sigorta veya bir faturayı ekle; hepsi tek yerde dursun."
        }
    }

    private func firstValueCTA(for g: OnboardingGoal) -> String {
        switch g {
        case .maintenance, .importantDates: return "Hatırlatma Ekle"
        case .expenses: return "Masraf Ekle"
        case .documents: return "Belge Ekle"
        }
    }

    private func firstValueSheetType(for g: OnboardingGoal) -> FirstValueSheet {
        switch g {
        case .maintenance, .importantDates: return .reminder
        case .expenses: return .expense
        case .documents: return .document
        }
    }

    private func firstValueCount(for g: OnboardingGoal) -> Int {
        switch firstValueSheetType(for: g) {
        case .reminder: return allReminders.count
        case .expense: return allExpenses.count
        case .document: return allDocuments.count
        }
    }

    @ViewBuilder
    private func firstValueForm(for sheet: FirstValueSheet) -> some View {
        let vehicleId = onboardingVehicle?.id
        switch sheet {
        case .reminder: ReminderFormView(preselectedVehicleId: vehicleId)
        case .expense: ExpenseFormView(preselectedVehicleId: vehicleId)
        case .document: DocumentFormView(preselectedVehicleId: vehicleId)
        }
    }

    private func handleFirstValueDismiss() {
        guard let g = goal, let baseline = firstValueBaseline else { return }
        firstValueBaseline = nil
        // Yeni bir kayıt eklendiyse ilk değer anı tamamlandı — bir sonraki adıma geç.
        if firstValueCount(for: g) > baseline {
            advance()
        }
    }

    // MARK: - Step 4 — Bildirim izni
    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            stepIcon("bell.badge.fill", color: AppColors.accentPrimary)
            stepHeadline(
                title: "Önemli tarihleri kaçırma",
                subtitle: "Muayene, sigorta ve bakım tarihleri yaklaşınca haber verebilmemiz için bildirim izni gerekiyor. Reklam veya gereksiz bildirim göndermiyoruz."
            )
            Text("İzin vermesen de uygulamayı kullanabilirsin; daha sonra Ayarlar'dan açabilirsin.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .onAppear {
            AnalyticsService.shared.log(.onboardingNotificationPromptViewed)
        }
    }

    // MARK: - Step 5 — Kişisel sonuç
    private var resultStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            stepIcon("checkmark.seal.fill", color: AppColors.success)
            stepHeadline(
                title: "Aracın için takip planı hazır.",
                subtitle: "Seçtiğin önceliğe göre başlangıç noktan hazırlandı. Garaj'dan devam edebilirsin."
            )
            VStack(spacing: AppSpacing.sm) {
                if let g = goal {
                    resultRow(icon: g.icon, title: "Önceliğin", value: g.title)
                }
                if let vehicle = onboardingVehicle {
                    resultRow(
                        icon: "car.fill",
                        title: "Aracın",
                        value: vehicle.fullName.isEmpty ? (vehicle.plate.isEmpty ? "Eklendi" : vehicle.plate) : vehicle.fullName
                    )
                }
                if let next = nextUpcomingReminder {
                    resultRow(icon: "bell.badge", title: "İlk yaklaşan iş", value: next.title)
                }
            }
        }
    }

    private var nextUpcomingReminder: Reminder? {
        allReminders
            .filter { $0.statusRaw != "Tamamlandı" && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .first
    }

    private func resultRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                Text(value)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    // MARK: - CTA Bar
    @ViewBuilder
    private var ctaBar: some View {
        VStack(spacing: AppSpacing.sm) {
            switch stepIndex {
            case 0:
                primaryButton("Başla") { advance() }
            case 1:
                primaryButton("Devam", enabled: goal != nil) { advanceFromGoal() }
                backButton
            case 2:
                if onboardingVehicle != nil {
                    primaryButton("Devam") { advance() }
                } else {
                    primaryButton("Devam", enabled: isVehicleValid) { saveVehicleAndAdvance() }
                }
                backButton
            case 3:
                primaryButton("Devam") { advance() }
                textButton("Daha sonra ekle") { advance() }
            case 4:
                primaryButton(notificationInFlight ? "..." : "Bildirimlere İzin Ver", enabled: !notificationInFlight) {
                    requestNotifications()
                }
                textButton("Şimdi Değil") {
                    // Kullanıcı sistem iznini hiç görmeden geçti — bir sistem "sonucu"
                    // olmadığı için permission_result loglanmaz, yalnızca ilerlenir.
                    advance()
                }
            default:
                primaryButton("Arvia'yı Kullanmaya Başla") { finishOnboarding() }
            }
        }
    }

    private func primaryButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private var backButton: some View {
        textButton("Geri") { goBack() }
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation
    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            stepIndex = min(stepIndex + 1, totalSteps - 1)
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.25)) {
            stepIndex = max(stepIndex - 1, 0)
        }
    }

    private func advanceFromGoal() {
        if let goal {
            AnalyticsService.shared.log(
                .onboardingGoalSelected,
                parameters: [.primaryGoal: .string(goal.analyticsValue)]
            )
        }
        advance()
    }

    // MARK: - Vehicle validation & save
    private var isVehicleValid: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedYear != nil
    }

    private var parsedYear: Int? {
        let digits = yearText.filter(\.isNumber)
        guard let year = Int(digits) else { return nil }
        guard year >= 1900, year <= currentYear + 1 else { return nil }
        return year
    }

    private func saveVehicleAndAdvance() {
        guard let year = parsedYear else {
            vehicleError = "Yıl 1900 ile \(currentYear + 1) arasında olmalıdır."
            return
        }
        let km = Int(kmText.filter(\.isNumber)) ?? 0
        let vehicle = Vehicle(
            plate: plate.trimmingCharacters(in: .whitespaces).uppercased(),
            brand: brand.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            year: year,
            currentOdometer: max(km, 0)
        )
        modelContext.insert(vehicle)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            vehicleError = "Araç kaydedilemedi. Lütfen tekrar dene."
            return
        }
        vehicleError = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AnalyticsService.shared.log(.onboardingVehicleAdded)
        AnalyticsService.shared.log(
            .vehicleAdded,
            parameters: [.vehicleCountBucket: AnalyticsService.vehicleCountBucket(activeVehicles.count)]
        )
        advance()
    }

    // MARK: - Notifications
    private func requestNotifications() {
        notificationInFlight = true
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                notificationInFlight = false
                AnalyticsService.shared.log(
                    .onboardingNotificationPermissionResult,
                    parameters: [.sourceScreen: .string("onboarding"), .granted: .bool(granted)]
                )
                advance()
            }
        }
    }

    // MARK: - Finish
    private func finishOnboarding() {
        stepIndex = 0
        onboardingVersion = OnboardingConstants.currentVersion
        AnalyticsService.shared.log(
            .onboardingCompleted,
            parameters: [
                .primaryGoal: .string(goal?.analyticsValue ?? "none"),
                .onboardingVersion: .int(OnboardingConstants.currentVersion),
            ]
        )
        onboardingCompleted = true
    }

    // MARK: - Shared bits
    private func stepIcon(_ name: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.10))
                .frame(width: 88, height: 88)
            Image(systemName: name)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(color)
        }
    }

    private func stepHeadline(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Onboarding Gate
/// AppRouter'ı sarmalayan onboarding gate. Yalnızca onboarding tamamlanmamışsa
/// akışı gösterir. Eski kullanıcılar (onboarding_completed == true) akışa
/// sokulmaz — sürüm yükseltmesi sessizce yapılır (bkz. VehicleDossierApp).
struct OnboardingGate<Content: View>: View {
    @AppStorage(OnboardingConstants.completedKey) private var onboardingCompleted = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if onboardingCompleted {
                content
            } else {
                OnboardingFlowView()
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingFlowView()
        .modelContainer(MockDataProvider.emptyPreviewContainer)
}
