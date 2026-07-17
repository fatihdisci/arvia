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
    @State private var saveError: String?

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
            .alert("Profil Kaydedilemedi", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(saveError ?? "Bilinmeyen hata")
            }
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
        // UI katmanında da gating var (VehicleDetailView, SettingsView vb.) ama bir
        // şekilde bu view'a free kullanıcı gelirse save'i engelle — SwiftData'da
        // Pro-özel veri birikmesin.
        guard paywallService.canUseAssistant else {
            dismiss()
            return
        }
        let trimmedUser = primaryUser.trimmingCharacters(in: .whitespaces)
        do {
            try service.saveGlobalProfile(
                dailyKmBand: dailyKmBand,
                routeType: routeType,
                fuelConsumptionCity: hasCityConsumption ? cityConsumption : nil,
                fuelConsumptionHighway: hasHighwayConsumption ? highwayConsumption : nil,
                primaryUser: trimmedUser.isEmpty ? nil : trimmedUser,
                tripTypes: Array(selectedTripTypes).sorted(),
                context: modelContext
            )
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Preview
#Preview("Kullanım Profili") {
    UsageProfileFlowView()
        .modelContainer(MockDataProvider.previewContainer)
}
