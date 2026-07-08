import SwiftUI
import SwiftData

// MARK: - Usage Profile Flow (Akıllı Sürüş Asistanı — Layer A)
// 5 kısa adım (her ekranda tek soru) + özet. Her adım atlanabilir. İlerleme göstergesi.
// Görsel dil: OnboardingView deseni + tasarım token'ları. Emoji yok, gradient yok.
struct UsageProfileFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var paywallService: PaywallService

    private let service = UsageProfileService.shared

    @State private var step = 0

    // Cevaplar
    @State private var dailyKmBand: DailyKmBand = .from20to50
    @State private var routeType: RouteType = .mixed
    @State private var hasCityConsumption = false
    @State private var cityConsumption: Double = 7.0
    @State private var hasHighwayConsumption = false
    @State private var highwayConsumption: Double = 6.0
    @State private var primaryUser = ""
    @State private var selectedTripTypes: Set<String> = []

    @State private var didLoad = false

    private let tripTypeOptions = [
        "İşe gidiş-geliş",
        "Uzun yol / seyahat",
        "Şehir içi kısa mesafe",
        "Ağır yük / ticari",
        "Hafta sonu / keyfi",
    ]

    private let totalSteps = 6 // 0..4 soru + 5 özet

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.top, AppSpacing.sm)

                ScrollView {
                    stepContent
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.lg)
                }

                bottomBar
                    .padding(.horizontal, AppSpacing.screenMarginH)
                    .padding(.bottom, AppSpacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Kullanım Profilim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                if step < totalSteps - 1 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Atla") { advance() }
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Progress
    private var progressBar: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? AppColors.accentPrimary : AppColors.border)
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            questionScaffold(
                icon: "gauge.with.needle",
                title: "Günde ortalama ne kadar yol yaparsın?",
                subtitle: "Kilometre tahmini ve bakım önerileri için kullanılır."
            ) {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(DailyKmBand.allCases) { band in
                        selectableRow(title: band.displayName, isSelected: dailyKmBand == band) {
                            dailyKmBand = band
                        }
                    }
                }
            }
        case 1:
            questionScaffold(
                icon: "road.lanes",
                title: "Çoğunlukla nerede sürersin?",
                subtitle: "Şehir içi ve otoyol kullanımı farklı aşınma yaratır."
            ) {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(RouteType.allCases) { route in
                        selectableRow(title: route.displayName, isSelected: routeType == route) {
                            routeType = route
                        }
                    }
                }
            }
        case 2:
            questionScaffold(
                icon: "fuelpump",
                title: "Ortalama yakıt tüketimin?",
                subtitle: "İsteğe bağlı. 100 km'de litre olarak."
            ) {
                VStack(spacing: AppSpacing.md) {
                    consumptionControl(
                        label: "Şehir içi",
                        isOn: $hasCityConsumption,
                        value: $cityConsumption
                    )
                    consumptionControl(
                        label: "Otoyol",
                        isOn: $hasHighwayConsumption,
                        value: $highwayConsumption
                    )
                }
            }
        case 3:
            questionScaffold(
                icon: "person",
                title: "Aracı çoğunlukla kim kullanıyor?",
                subtitle: "İsteğe bağlı. Örn. Ben, Eşim, Şirket."
            ) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.text.rectangle").foregroundColor(AppColors.textTertiary)
                    TextField("İsim veya rol", text: $primaryUser)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(AppSpacing.md)
                .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
            }
        case 4:
            questionScaffold(
                icon: "list.bullet",
                title: "Genelde ne tür sürüşler yaparsın?",
                subtitle: "Birden fazla seçebilirsin."
            ) {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(tripTypeOptions, id: \.self) { option in
                        selectableRow(title: option, isSelected: selectedTripTypes.contains(option)) {
                            if selectedTripTypes.contains(option) {
                                selectedTripTypes.remove(option)
                            } else {
                                selectedTripTypes.insert(option)
                            }
                        }
                    }
                }
            }
        default:
            summaryStep
        }
    }

    // MARK: - Summary
    private var summaryStep: some View {
        questionScaffold(
            icon: "steeringwheel",
            title: "Profilin hazır",
            subtitle: "Bu bilgileri Ayarlar'dan istediğin zaman güncelleyebilirsin."
        ) {
            VStack(spacing: AppSpacing.xs) {
                summaryRow(label: "Günlük yol", value: dailyKmBand.displayName)
                summaryRow(label: "Sürüş bölgesi", value: routeType.displayName)
                if hasCityConsumption {
                    summaryRow(label: "Şehir tüketimi", value: String(format: "%.1f L/100km", cityConsumption))
                }
                if hasHighwayConsumption {
                    summaryRow(label: "Otoyol tüketimi", value: String(format: "%.1f L/100km", highwayConsumption))
                }
                if !primaryUser.trimmingCharacters(in: .whitespaces).isEmpty {
                    summaryRow(label: "Sürücü", value: primaryUser)
                }
                if !selectedTripTypes.isEmpty {
                    summaryRow(label: "Sürüş tipleri", value: selectedTripTypes.sorted().joined(separator: ", "))
                }
            }
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        Button {
            if step < totalSteps - 1 {
                advance()
            } else {
                saveAndFinish()
            }
        } label: {
            Text(step < totalSteps - 1 ? "Devam" : "Kaydet")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary)
    }

    // MARK: - Reusable pieces
    private func questionScaffold<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentPrimary.opacity(0.08))
                        .frame(width: 88, height: 88)
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(AppColors.accentPrimary)
                }
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            content()
        }
    }

    private func selectableRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.accentPrimary : AppColors.textTertiary)
                Text(title)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(isSelected ? AppColors.accentPrimary : AppColors.border, lineWidth: isSelected ? 1.2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func consumptionControl(label: String, isOn: Binding<Bool>, value: Binding<Double>) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Toggle(isOn: isOn) {
                Text(label)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.accentPrimary)

            if isOn.wrappedValue {
                HStack {
                    Slider(value: value, in: 2...25, step: 0.5)
                        .tint(AppColors.accentPrimary)
                    Text(String(format: "%.1f", value.wrappedValue))
                        .font(AppTypography.amountMd)
                        .foregroundColor(AppColors.accentPrimary)
                        .frame(width: 52, alignment: .trailing)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(AppTypography.secondaryMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, AppSpacing.xxs)
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(Color.appSurface))
    }

    // MARK: - Logic
    private func advance() {
        withAnimation { step = min(step + 1, totalSteps - 1) }
    }

    private func loadExisting() {
        guard !didLoad else { return }
        didLoad = true
        guard let profile = service.globalProfile(context: modelContext) else { return }
        dailyKmBand = profile.dailyKmBand
        routeType = profile.routeType
        if let city = profile.fuelConsumptionCity {
            hasCityConsumption = true
            cityConsumption = city
        }
        if let hw = profile.fuelConsumptionHighway {
            hasHighwayConsumption = true
            highwayConsumption = hw
        }
        primaryUser = profile.primaryUser ?? ""
        selectedTripTypes = Set(profile.tripTypes)
    }

    private func saveAndFinish() {
        // Defense-in-depth: Kullanım profili yalnızca Pro'ya açık (Akıllı Sürüş Asistanı feature'ı).
        // UI katmanında da gating var (AssistantView, AppRouter vb.) ama bir şekilde
        // bu view'a free kullanıcı gelirse save'i engelle — SwiftData'da Pro-özel veri
        // birikmesin.
        guard paywallService.canUseAssistant else {
            dismiss()
            return
        }
        let trimmedUser = primaryUser.trimmingCharacters(in: .whitespaces)
        service.saveGlobalProfile(
            dailyKmBand: dailyKmBand,
            routeType: routeType,
            fuelConsumptionCity: hasCityConsumption ? cityConsumption : nil,
            fuelConsumptionHighway: hasHighwayConsumption ? highwayConsumption : nil,
            primaryUser: trimmedUser.isEmpty ? nil : trimmedUser,
            tripTypes: Array(selectedTripTypes).sorted(),
            context: modelContext
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Preview
#Preview("Kullanım Profili") {
    UsageProfileFlowView()
        .modelContainer(MockDataProvider.previewContainer)
}

// MARK: - Assistant Tab (Akıllı Sürüş Asistanı ana ekranı)
// İki ana bölüm: Hero + Maintenance Plan + Kullanım Profili.
// Pro kullanıcıya son oluşturulan bakım planı önerileri varsayılan olarak
// açılmış liste halinde gösterilir (sheet açmaya gerek yok). Free kullanıcıya
// aynı tasarımda demo öneriler + paywall CTA gösterilir — ekran "bu Pro özelliğin
// önizlemesi" gibi çalışır. Kullanım profili kartı zaten Pro gate'li.
struct AssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var paywallService: PaywallService
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var allUsageProfiles: [VehicleUsageProfile]

    @State private var selectedVehicleId: UUID?
    @State private var showProfileFlow = false
    @State private var maintenancePlanVehicle: Vehicle?
    @State private var showPaywall = false
    @State private var showAIConsent = false
    @State private var pendingReminderDraft: AssistantReminderDraft?

    private var activeVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt == nil }
    }

    private var selectedVehicle: Vehicle? {
        if let id = selectedVehicleId, let v = activeVehicles.first(where: { $0.id == id }) {
            return v
        }
        return activeVehicles.first
    }

    private var globalProfile: VehicleUsageProfile? {
        allUsageProfiles
            .filter { $0.appliesToAllVehicles }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    heroSection

                    if let vehicle = selectedVehicle {
                        if activeVehicles.count > 1 {
                            vehiclePicker
                        }
                        maintenancePlanSection(for: vehicle)
                    }

                    usageProfileCard

                    if selectedVehicle == nil {
                        addVehicleHint
                    }

                    Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
                }
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Asistan")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showProfileFlow) {
                UsageProfileFlowView()
            }
            .sheet(item: $maintenancePlanVehicle) { vehicle in
                MaintenancePlanView(vehicle: vehicle)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: .assistant)
            }
            .sheet(isPresented: $showAIConsent) {
                AIConsentView(
                    onAccept: {
                        UserDefaults.standard.set(true, forKey: AIConsentStore.consentKey)
                        UserDefaults.standard.set(true, forKey: AIConsentStore.enabledKey)
                        if let vehicle = selectedVehicle {
                            maintenancePlanVehicle = vehicle
                        }
                    },
                    onDecline: {}
                )
            }
            .sheet(item: $pendingReminderDraft) { draft in
                ReminderFormView(
                    preselectedVehicleId: selectedVehicle?.id,
                    prefilledTitle: draft.title,
                    prefilledDueOdometer: draft.dueOdometer,
                    prefilledDueInMonths: draft.dueInMonths
                )
            }
        }
    }

    // MARK: - Hero
    /// Üst başlık şeridi — sayfanın ne hakkında olduğunu bir cümleyle özetler.
    /// Pro ise "yapay zekâ destekli" vurgusu, free ise daha temkinli bir tanıtım.
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.accentPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Akıllı Sürüş Asistanı")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text(paywallService.canUseAssistant
                         ? "Kullanımına göre kişisel bakım önerileri ve kilometre tahmini."
                         : "Pro ile yapay zekâ destekli kişisel bakım önerileri.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Usage Profile Card
    /// Kullanım profili kartı — Akıllı Sürüş Asistanı'nın parçası olduğu için
    /// yalnızca Pro kullanıcıda interaktif. Free kullanıcıya kilitli bir özet
    /// gösterilir ve tıklayınca paywall açılır — bu sayede free hesapta
    /// kullanım profili oluşturulamaz/düzenlenemez.
    @ViewBuilder
    private var usageProfileCard: some View {
        if paywallService.canUseAssistant {
            if let profile = globalProfile {
                filledProfileCard(profile)
            } else {
                emptyProfileCard
            }
        } else {
            lockedProfileCard
        }
    }

    /// Free kullanıcıya gösterilen kilitli kart — mevcut profili (varsa) özetler
    /// ve CTA olarak paywall açar. PredictiveOdometerService / MaintenanceAdvisorService
    /// çağrıları `canUseAssistant` guard'lı olduğu için bu kart sadece bilgi amaçlı;
    /// düzenleme/oluşturma yok.
    private var lockedProfileCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.accentPrimary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.text.rectangle")
                        .font(.title3)
                        .foregroundColor(AppColors.accentPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kullanım Profilin")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(lockedProfileSubtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Text("Pro")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppColors.accentPrimary))
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var lockedProfileSubtitle: String {
        if let profile = globalProfile {
            return "Günlük yol: \(profile.dailyKmBand.displayName) — düzenlemek için Pro gerekli."
        }
        return "Sürüş alışkanlıklarını kaydetmek için Pro gerekli."
    }

    /// Doldurulmuş profil — pasif (salt-okunur) + tikli, yanında "Düzenle".
    private func filledProfileCard(_ profile: VehicleUsageProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.success)
                Text("Kullanım Profilin")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
                Button {
                    showProfileFlow = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Düzenle")
                            .font(AppTypography.captionMedium)
                    }
                    .foregroundColor(AppColors.accentPrimary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.accentPrimary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kullanım profilini düzenle")
            }

            VStack(spacing: 0) {
                profileRow(label: "Günlük yol", value: profile.dailyKmBand.displayName)
                Divider().overlay(AppColors.border)
                profileRow(label: "Sürüş bölgesi", value: profile.routeType.displayName)
                if let city = profile.fuelConsumptionCity {
                    Divider().overlay(AppColors.border)
                    profileRow(label: "Şehir tüketimi", value: String(format: "%.1f L/100km", city))
                }
                if let hw = profile.fuelConsumptionHighway {
                    Divider().overlay(AppColors.border)
                    profileRow(label: "Otoyol tüketimi", value: String(format: "%.1f L/100km", hw))
                }
                if let user = profile.primaryUser, !user.isEmpty {
                    Divider().overlay(AppColors.border)
                    profileRow(label: "Sürücü", value: user)
                }
                if !profile.tripTypes.isEmpty {
                    Divider().overlay(AppColors.border)
                    profileRow(label: "Sürüş tipleri", value: profile.tripTypes.joined(separator: ", "))
                }
            }
            .padding(.vertical, AppSpacing.xxs)
            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(AppColors.backgroundSecondary.opacity(0.5)))

            Text("Bu bilgiler kişisel bakım planı ve kilometre tahmini için kullanılır.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(AppTypography.secondaryMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// Profil yoksa — kurulum kartı.
    private var emptyProfileCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
                Text("Kullanım profilini oluştur")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            Text("Günlük yolun, sürüş bölgen ve alışkanlıkların birkaç adımda kaydedilir; öneriler buna göre kişiselleşir.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showProfileFlow = true
            } label: {
                Text("Başla").frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .padding(.top, AppSpacing.xxs)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }

    // MARK: - Vehicle Picker (çoklu araç)
    private var vehiclePicker: some View {
        Menu {
            ForEach(activeVehicles) { v in
                Button {
                    selectedVehicleId = v.id
                } label: {
                    HStack {
                        Text(v.plate.isEmpty ? v.fullName : v.plate)
                        if selectedVehicle?.id == v.id { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "car.fill").font(.caption2)
                Text(selectedVehicle.map { $0.plate.isEmpty ? $0.fullName : $0.plate } ?? "Araç")
                    .font(AppTypography.captionMedium)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundColor(AppColors.accentPrimary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Capsule().fill(AppColors.accentPrimary.opacity(0.1)))
        }
    }

    // MARK: - Maintenance Plan Section
    /// Bakım planı bölümü — Pro + AI açıkken son cache'i varsayılan olarak
    /// açılmış liste halinde gösterir (kullanıcı sheet açmak zorunda değil);
    /// free kullanıcıya demo öneriler + paywall CTA gösterir.
    /// NOT: ScrollView içinde expand/collapse YOK. İçerik her zaman açık,
    /// komşu kartların yeniden yerleşmesine bağlı takılma yok.
    @ViewBuilder
    private func maintenancePlanSection(for vehicle: Vehicle) -> some View {
        let isPro = paywallService.canUseAssistant
        let aiEnabled = AIConsentStore.shared.isCloudAIEnabled
        let cached = isPro ? MaintenancePlanCacheStore.load(vehicleId: vehicle.id) : nil

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(
                icon: "steeringwheel",
                title: "Kişisel Bakım Planı",
                subtitle: sectionSubtitle(isPro: isPro, aiEnabled: aiEnabled, cached: cached)
            )

            // İçerik
            if !isPro {
                demoSuggestionsList
                freeCTAFooter
            } else if !aiEnabled {
                aiDisabledCallout(vehicle: vehicle)
            } else if let cached, !cached.suggestions.isEmpty {
                suggestionsList(cached.suggestions, vehicle: vehicle)
                refreshFooter(vehicle: vehicle)
            } else {
                emptyPlanCallout(vehicle: vehicle)
            }
        }
    }

    /// Bölüm başlık satırı: icon + başlık + subtitle.
    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.accentPrimary.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func sectionSubtitle(isPro: Bool, aiEnabled: Bool, cached: MaintenancePlanCacheStore.Cached?) -> String {
        if !isPro {
            return "Pro ile kullanımına göre kişiselleştirilmiş öneriler."
        }
        if !aiEnabled {
            return "Bulut AI kapalı — açman gerekiyor."
        }
        if let cached, !cached.suggestions.isEmpty {
            let date = cached.createdAt.formatted(date: .abbreviated, time: .omitted)
            return "Son plan · \(date). Araç verisi değişince yenilenir."
        }
        return "Henüz planın yok. Bir tane oluşturalım."
    }

    /// Pro + cache var: öneriler liste halinde, her biri kompakt kart.
    @ViewBuilder
    private func suggestionsList(_ suggestions: [MaintenancePlanSuggestion], vehicle: Vehicle) -> some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(Array(suggestions.prefix(3).enumerated()), id: \.offset) { index, suggestion in
                suggestionCard(
                    suggestion: suggestion,
                    index: index + 1,
                    vehicle: vehicle,
                    isDemo: false
                )
            }
        }
    }

    /// Free: gerçekçi demo öneriler (statik) — kullanıcı Pro olunca ne göreceğini
    /// anlasın. Kilitli badge'lerle değil, normal kart görünümünde — sadece
    /// CTA footer "Pro'ya Geç" ile kilit vurgulanır.
    private var demoSuggestionsList: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(Array(AssistantDemoData.suggestions.enumerated()), id: \.offset) { index, suggestion in
                suggestionCard(
                    suggestion: suggestion,
                    index: index + 1,
                    vehicle: nil,
                    isDemo: true
                )
            }
        }
    }

    /// Tek bir öneri kartı — Pro ve demo için ortak.
    /// Pro: hatırlatıcı oluştur butonu aktif.
    /// Demo: buton yerinde "Pro ile dene" placeholder veya yok.
    @ViewBuilder
    private func suggestionCard(suggestion: MaintenancePlanSuggestion, index: Int, vehicle: Vehicle?, isDemo: Bool) -> some View {
        let color = severityColor(suggestion.severity)
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Text("\(index)")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(color.opacity(0.14)))
                Text(suggestion.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: severityIcon(suggestion.severity))
                    .font(.caption)
                    .foregroundColor(color)
            }
            Text(suggestion.message)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if suggestion.suggestedIntervalKm != nil || suggestion.suggestedIntervalMonths != nil {
                HStack(spacing: AppSpacing.xs) {
                    if let km = suggestion.suggestedIntervalKm {
                        intervalChip(text: "~\(km.formatted()) km", icon: "gauge.with.needle")
                    }
                    if let months = suggestion.suggestedIntervalMonths {
                        intervalChip(text: "~\(months) ay", icon: "calendar")
                    }
                }
            }

            if !isDemo, let vehicle {
                Button {
                    let draft = AssistantReminderDraft(
                        title: suggestion.title,
                        dueOdometer: suggestion.suggestedIntervalKm.map { vehicle.currentOdometer + $0 },
                        dueInMonths: suggestion.suggestedIntervalMonths
                    )
                    pendingReminderDraft = draft
                } label: {
                    Label("Hatırlatıcı oluştur", systemImage: "bell.badge")
                        .font(AppTypography.secondaryMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, AppSpacing.sm)
        }
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }

    /// Pro + cache var — altta "Yenile" link'i (sheet açarak yeni plan üretir).
    private func refreshFooter(vehicle: Vehicle) -> some View {
        Button {
            maintenancePlanVehicle = vehicle
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                Text("Yenile")
                    .font(AppTypography.secondaryMedium)
            }
            .foregroundColor(AppColors.accentPrimary)
            .padding(.top, AppSpacing.xxs)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// Pro + AI enabled + cache yok — "Plan Oluştur" CTA (dolgun primary buton).
    private func emptyPlanCallout(vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Kullanım profilin ve araç verilerine göre 3 öneri hazırlayalım.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                maintenancePlanVehicle = vehicle
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "sparkles")
                    Text("Plan Oluştur")
                }
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.accentPrimary)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }

    /// Pro + AI disabled — "Bulut AI'yı aç" CTA (AIConsentView açılır).
    private func aiDisabledCallout(vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Kişisel bakım planı için bulut AI özelliğinin açık olması gerekir.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showAIConsent = true
            } label: {
                Text("Bulut AI'yı aç")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm + 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .fill(AppColors.accentPrimary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }

    /// Free — bölümün altında dolgun paywall CTA.
    private var freeCTAFooter: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "crown.fill")
                Text("Pro ile Kişiselleştirilmiş Plan")
            }
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColors.accentPrimary)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.xs)
    }

    private func intervalChip(text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(text)
                .font(AppTypography.caption)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.backgroundSecondary))
    }

    private func severityIcon(_ severity: String) -> String {
        switch severity {
        case "important": return "exclamationmark.triangle.fill"
        case "warning": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "important": return AppColors.critical
        case "warning": return AppColors.warning
        default: return AppColors.accentPrimary
        }
    }

    // MARK: - Add Vehicle Hint
    private var addVehicleHint: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "car.badge.gearshape")
                .font(.body)
                .foregroundColor(AppColors.textTertiary)
            Text("Kişisel bakım planı için Garaj'dan bir araç ekle.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(AppColors.backgroundSecondary.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }
}

#Preview("Asistan") {
    AssistantView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
}

// MARK: - Assistant Reminder Draft
/// Asistan kartındaki "Hatırlatıcı oluştur" butonundan ReminderFormView'e
/// aktarılacak ön-doldurulmuş değerler. MaintenancePlanView'deki ReminderDraft
/// private olduğu için burada ayrı bir tür tanımlıyoruz; aynı şema.
struct AssistantReminderDraft: Identifiable {
    let id = UUID()
    let title: String
    let dueOdometer: Int?
    let dueInMonths: Int?
}

// MARK: - Assistant Demo Data
/// Free kullanıcıya gösterilen örnek öneri listesi — gerçek AI çıktısı değil,
/// Pro'nun ne sunduğunu anlatmak için statik örnekler. Pro olduğunda bu liste
/// yerine MaintenancePlanCacheStore'dan gerçek öneriler gösterilir.
enum AssistantDemoData {
    static let suggestions: [MaintenancePlanSuggestion] = [
        MaintenancePlanSuggestion(
            title: "Motor yağı ve filtre değişimi",
            message: "Sentetik yağ 10.000 km'de, mineral yağ 5.000 km'de değişmelidir. Şehir içi kısa mesafe kullanımda aralık kısalır.",
            severity: "info",
            suggestedIntervalKm: 10_000,
            suggestedIntervalMonths: 12
        ),
        MaintenancePlanSuggestion(
            title: "Hava filtresi kontrolü",
            message: "Tozlu yollarda daha sık kontrol önerilir. Kirli filtre yakıt tüketimini %5-10 artırabilir.",
            severity: "warning",
            suggestedIntervalKm: 20_000,
            suggestedIntervalMonths: 24
        ),
        MaintenancePlanSuggestion(
            title: "Fren balata kontrolü",
            message: "Ön balatalar 30-50 bin km arası dayanır. Şehir içi yoğun kullanımda erken aşınma olabilir.",
            severity: "important",
            suggestedIntervalKm: 35_000,
            suggestedIntervalMonths: nil
        ),
    ]
}

