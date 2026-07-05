import SwiftUI
import SwiftData

// MARK: - Usage Profile Flow (Akıllı Sürüş Asistanı — Layer A)
// 5 kısa adım (her ekranda tek soru) + özet. Her adım atlanabilir. İlerleme göstergesi.
// Görsel dil: OnboardingView deseni + tasarım token'ları. Emoji yok, gradient yok.
struct UsageProfileFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
            icon: "brain.head.profile",
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
// Kullanım profili + kişisel bakım planı tek sekmede toplanır.
// Kullanım profili doldurulduysa pasif (salt-okunur) ve tikli gösterilir,
// yanında "Düzenle" butonuyla; boşsa kurulum kartı çıkar.
struct AssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var paywallService: PaywallService
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var allUsageProfiles: [VehicleUsageProfile]
    @Query(sort: \ServiceRecord.date, order: .reverse) private var allServiceRecords: [ServiceRecord]

    @State private var selectedVehicleId: UUID?
    @State private var showProfileFlow = false
    @State private var maintenancePlanVehicle: Vehicle?
    @State private var showPaywall = false

    // MARK: - Inline Maintenance Plan State
    private enum PlanStage: Equatable {
        case waiting
        case generating
        case ready
        case unavailable
        case failed(String)
    }

    @State private var planStage: PlanStage = .waiting
    @State private var planSuggestions: [MaintenancePlanSuggestion] = []
    @State private var isPlanExpanded = true
    @State private var planFromCache = false
    @State private var planVehicleId: UUID?
    @State private var reminderDraft: ReminderDraft?

    private struct ReminderDraft: Identifiable {
        let id = UUID()
        let title: String
        let dueOdometer: Int?
        let dueInMonths: Int?
    }

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
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("Sürüş alışkanlıklarına göre sana özel bakım önerileri ve kilometre tahmini.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.screenMarginH)

                    if let vehicle = selectedVehicle {
                        if activeVehicles.count > 1 {
                            vehiclePicker
                                .padding(.horizontal, AppSpacing.screenMarginH)
                        }
                        maintenancePlanSection(for: vehicle)
                            .padding(.horizontal, AppSpacing.screenMarginH)
                        usageProfileCard
                            .padding(.horizontal, AppSpacing.screenMarginH)
                    } else {
                        usageProfileCard
                            .padding(.horizontal, AppSpacing.screenMarginH)
                        addVehicleHint
                            .padding(.horizontal, AppSpacing.screenMarginH)
                    }

                    Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
                }
                .padding(.vertical, AppSpacing.md)
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
            .sheet(item: $reminderDraft) { draft in
                ReminderFormView(
                    preselectedVehicleId: selectedVehicle?.id,
                    prefilledTitle: draft.title,
                    prefilledDueOdometer: draft.dueOdometer,
                    prefilledDueInMonths: draft.dueInMonths
                )
            }
            .onAppear { loadCachedPlan() }
            .onChange(of: selectedVehicle?.id) { _, _ in loadCachedPlan() }
        }
    }

    // MARK: - Usage Profile Card
    @ViewBuilder
    private var usageProfileCard: some View {
        if let profile = globalProfile {
            filledProfileCard(profile)
        } else {
            emptyProfileCard
        }
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

    // MARK: - Maintenance Plan Section (Expandable, Inline)
    @ViewBuilder
    private func maintenancePlanSection(for vehicle: Vehicle) -> some View {
        let canUse = paywallService.canUseAssistant && AIConsentStore.shared.isCloudAIEnabled

        VStack(spacing: 0) {
            // Header — always visible
            Button {
                if canUse {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPlanExpanded.toggle()
                    }
                    if isPlanExpanded, planStage == .waiting {
                        generatePlan(for: vehicle)
                    }
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(AppColors.accentPrimary.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                            .foregroundColor(AppColors.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kişisel Bakım Planı")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text(planSubtitle(canUse: canUse))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    if canUse {
                        Image(systemName: isPlanExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    } else {
                        Text("Pro")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textOnAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.accentPrimary))
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: isPlanExpanded && canUse
                        ? AppRadius.heroCard : AppRadius.card)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isPlanExpanded && canUse
                        ? AppRadius.heroCard : AppRadius.card)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // Expanded content
            if isPlanExpanded, canUse {
                VStack(spacing: AppSpacing.sm) {
                    Divider().overlay(AppColors.border)

                    planExpandedContent(for: vehicle)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.md)
                }
                .background(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: AppRadius.card,
                        bottomTrailingRadius: AppRadius.card
                    )
                    .fill(Color.appSurface)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: AppRadius.card,
                        bottomTrailingRadius: AppRadius.card
                    )
                    .stroke(AppColors.border, lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func planSubtitle(canUse: Bool) -> String {
        guard canUse else {
            return "Yapay zekâ ile sana özel bakım önerileri (Pro)"
        }
        switch planStage {
        case .waiting:
            return "Plan yükleniyor…"
        case .generating:
            return "Plan hazırlanıyor…"
        case .ready:
            let count = planSuggestions.count
            if count == 0 {
                return "Şu an için özel bir öneri yok"
            }
            let prefix = planFromCache ? "Son plan" : "Planın hazır"
            return "\(prefix) · \(count) öneri"
        case .unavailable:
            return "Bulut AI kapalı — ayarlardan açabilirsin"
        case .failed(let msg):
            return msg
        }
    }

    // MARK: - Expanded Content
    @ViewBuilder
    private func planExpandedContent(for vehicle: Vehicle) -> some View {
        switch planStage {
        case .waiting:
            HStack(spacing: AppSpacing.sm) {
                ProgressView().tint(AppColors.accentPrimary).scaleEffect(0.8)
                Text("Plan yükleniyor…")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: .infinity)

        case .generating:
            VStack(spacing: AppSpacing.md) {
                ProgressView().tint(AppColors.accentPrimary).scaleEffect(1.1)
                Text("Kullanım profiline göre öneriler oluşturuluyor")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, AppSpacing.xl)
            .frame(maxWidth: .infinity)

        case .ready:
            if planSuggestions.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.success)
                    Text("Şu an için özel bir öneri yok.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Kayıtların arttıkça plan daha isabetli olur.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.vertical, AppSpacing.lg)
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(planSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        premiumSuggestionCard(suggestion, index: index + 1)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        if planFromCache {
                            Label("Önbellekten", systemImage: "clock.arrow.circlepath")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                        Button {
                            generatePlan(for: vehicle, force: true)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(AppColors.accentPrimary)
                        }
                        .accessibilityLabel("Planı yenile")
                    }
                    .padding(.top, AppSpacing.xxs)
                }
            }

        case .unavailable:
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(AppColors.textTertiary)
                Text("Bulut AI kapalı")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                Text("Kişisel bakım planı için Pro ve bulut AI özelliklerinin açık olması gerekir.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                Button("Bulut AI'yı aç") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.secondary)
                .padding(.top, AppSpacing.xxs)
            }
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)

        case .failed(let message):
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title3)
                    .foregroundColor(AppColors.textTertiary)
                Text(message)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    generatePlan(for: vehicle, force: true)
                } label: {
                    Text("Tekrar dene")
                        .font(AppTypography.secondaryMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Premium Suggestion Card
    private func premiumSuggestionCard(_ suggestion: MaintenancePlanSuggestion, index: Int) -> some View {
        let color = severityColor(suggestion.severity)

        return HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header row: severity dot + title
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(suggestion.title)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer(minLength: 0)
                }

                Text(suggestion.message)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Interval chips
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

                // Action
                Button {
                    reminderDraft = ReminderDraft(
                        title: suggestion.title,
                        dueOdometer: suggestion.suggestedIntervalKm.map { vehicleOdometer + $0 },
                        dueInMonths: suggestion.suggestedIntervalMonths
                    )
                } label: {
                    Label("Hatırlatıcı oluştur", systemImage: "bell.badge")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .padding(.trailing, AppSpacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var vehicleOdometer: Int {
        selectedVehicle?.currentOdometer ?? 0
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.backgroundSecondary)
        )
    }

    // MARK: - Plan Logic
    private func loadCachedPlan() {
        guard let vehicle = selectedVehicle else { return }

        if planVehicleId != vehicle.id {
            planVehicleId = vehicle.id
            planSuggestions = []
            planStage = .waiting
            planFromCache = false
        }

        guard planStage == .waiting else { return }

        guard paywallService.canUseAssistant, AIConsentStore.shared.isCloudAIEnabled else {
            planStage = .unavailable
            return
        }

        // Try cache
        if let cached = MaintenancePlanCacheStore.load(vehicleId: vehicle.id),
           MaintenancePlanCacheStore.isFresh(cached) {
            let payload = buildPlanPayload(for: vehicle)
            if cached.inputHash == MaintenancePlanCacheStore.fingerprint(payload) {
                planSuggestions = cached.suggestions
                planStage = .ready
                planFromCache = true
                return
            }
        }

        // Auto-generate if expanded
        if isPlanExpanded {
            generatePlan(for: vehicle)
        }
    }

    private func generatePlan(for vehicle: Vehicle, force: Bool = false) {
        guard paywallService.canUseAssistant,
              AIConsentStore.shared.isCloudAIEnabled else {
            planStage = .unavailable
            return
        }

        // Generate only from waiting or failed states, unless forced
        if !force {
            switch planStage {
            case .waiting, .failed: break
            default: return
            }
        }

        planStage = .generating
        let payload = buildPlanPayload(for: vehicle)
        let inputHash = MaintenancePlanCacheStore.fingerprint(payload)

        // Check cache for force=false
        if !force,
           let cached = MaintenancePlanCacheStore.load(vehicleId: vehicle.id),
           MaintenancePlanCacheStore.isFresh(cached),
           cached.inputHash == inputHash {
            planSuggestions = cached.suggestions
            planStage = .ready
            planFromCache = true
            return
        }

        Task {
            do {
                let result = try await AIProxyService.shared.maintenancePlan(profileJSON: payload)
                await MainActor.run {
                    planSuggestions = Array(result.prefix(3))
                    MaintenancePlanCacheStore.save(planSuggestions, vehicleId: vehicle.id, inputHash: inputHash)
                    planStage = .ready
                    planFromCache = false
                }
            } catch let error as AIProxyError {
                await MainActor.run {
                    switch error {
                    case .disabled:
                        planStage = .unavailable
                    case .quotaExceeded:
                        planStage = .failed("Yapay zekâ ay limitine ulaşıldı. Kural tabanlı öneriler çalışmaya devam ediyor.")
                    default:
                        planStage = .failed("Plan oluşturulamadı. Daha sonra tekrar dene.")
                    }
                }
            } catch {
                await MainActor.run {
                    planStage = .failed("Plan oluşturulamadı. Daha sonra tekrar dene.")
                }
            }
        }
    }

    private func buildPlanPayload(for vehicle: Vehicle) -> String {
        let profile = UsageProfileService.resolve(for: vehicle.id, from: allUsageProfiles)
        let recent = allServiceRecords
            .filter { $0.vehicleId == vehicle.id }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { MaintenancePlanPayloadBuilder.ServiceLine(title: $0.serviceType.displayName, km: $0.odometer) }

        let input = MaintenancePlanPayloadBuilder.Input(
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year,
            fuelType: vehicle.fuelType.rawValue,
            odometer: vehicle.currentOdometer,
            dailyKmBand: profile?.dailyKmBand.rawValue,
            routeType: profile?.routeType.rawValue,
            fuelConsumptionCity: profile?.fuelConsumptionCity,
            fuelConsumptionHighway: profile?.fuelConsumptionHighway,
            primaryUser: profile?.primaryUser,
            tripTypes: profile?.tripTypes ?? [],
            recentServices: Array(recent)
        )
        return MaintenancePlanPayloadBuilder.build(input)
    }

    // MARK: - Helpers
    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "important": return AppColors.critical
        case "warning":   return AppColors.warning
        default:          return AppColors.accentPrimary
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

