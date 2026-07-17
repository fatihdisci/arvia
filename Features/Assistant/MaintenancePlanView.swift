import SwiftUI
import SwiftData

// MARK: - Maintenance Plan View (LLM-deepened, on-demand)
// Kullanıcı tetikler (otomatik değil). Pro + AI onayı + ana toggle gerekir.
// ≤3 öneri kart olarak gösterilir; her kart mevcut hatırlatıcı akışını
// suggestedIntervalKm/Months ile önden doldurur. Sonuç 30 gün yerelde önbelleklenir.
struct MaintenancePlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    @Query private var allUsageProfiles: [VehicleUsageProfile]
    @Query private var allServiceRecords: [ServiceRecord]

    private enum Stage: Equatable {
        case idle
        case loading
        case loaded(fromCache: Bool)
        case unavailable
        case failed(String)
    }

    @State private var stage: Stage = .idle
    @State private var suggestions: [MaintenancePlanSuggestion] = []
    @State private var reminderDraft: ReminderDraft?
    @State private var showAIConsent = false

    private struct ReminderDraft: Identifiable {
        let id = UUID()
        let title: String
        let dueOdometer: Int?
        let dueInMonths: Int?
    }

    private var aiAvailable: Bool {
        PaywallService.shared.isPro && AIConsentStore.shared.isCloudAIEnabled
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.appBackground)
                .navigationTitle("Kişisel Bakım Planı")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { dismiss() }
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if case .loaded = stage {
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                generate(force: true)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(AppColors.accentPrimary)
                            }
                            .accessibilityLabel("Yeniden oluştur")
                        }
                    }
                }
                .sheet(item: $reminderDraft) { draft in
                    ReminderFormView(
                        preselectedVehicleId: vehicle.id,
                        prefilledTitle: draft.title,
                        prefilledDueOdometer: draft.dueOdometer,
                        prefilledDueInMonths: draft.dueInMonths
                    )
                }
                .sheet(isPresented: $showAIConsent) {
                    AIConsentView(
                        onAccept: {
                            UserDefaults.standard.set(true, forKey: AIConsentStore.consentKey)
                            UserDefaults.standard.set(true, forKey: AIConsentStore.enabledKey)
                            generate(force: true)
                        },
                        onDecline: {}
                    )
                }
                .onAppear(perform: loadInitial)
        }
        // Sabit detent'ler olmadan sheet, stage değiştikçe (loading → loaded)
        // içerik yüksekliğini yeniden hesaplıyor; bu da kapanışta görülen
        // takılmanın kaynağıydı. Sabit detent + drag indicator, ArviaGuideSection'daki
        // gibi native bir bottom-sheet hissi veriyor (açılır liste değil, kart).
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .idle, .loading:
            loadingView.transition(.opacity)
        case .loaded(let fromCache):
            loadedView(fromCache: fromCache).transition(.opacity)
        case .unavailable:
            unavailableView.transition(.opacity)
        case .failed(let message):
            failedView(message).transition(.opacity)
        }
    }

    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView().tint(AppColors.accentPrimary).scaleEffect(1.3)
            Text("Plan hazırlanıyor…")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("Kullanımına göre öneriler oluşturuluyor")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func loadedView(fromCache: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                planHeader

                if suggestions.isEmpty {
                    Text("Şu an için özel bir öneri yok. Kayıtların arttıkça plan daha isabetli olur.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.screenMarginH)
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                            suggestionCard(suggestion, index: index + 1)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMarginH)
                }

                if fromCache {
                    Label("Yerel kopyadan gösteriliyor. Yenilemek için ↻.", systemImage: "clock.arrow.circlepath")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.screenMarginH)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    /// Plan başlığı — ham liste değil, kısaca bağlamlandırılmış bir özet.
    private var planHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.accentPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestions.isEmpty ? "Şimdilik önerin yok" : "\(suggestions.count) öneri hazır")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text("Kullanım profiline ve bakım geçmişine göre kişiselleştirildi.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    /// Sıra numarası + şiddet rengi aksan şeridi — düz bir liste yerine
    /// önceliklendirilmiş bir plan hissi verir.
    private func suggestionCard(_ suggestion: MaintenancePlanSuggestion, index: Int) -> some View {
        let color = severityColor(suggestion.severity)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text("\(index)")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(color)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(color.opacity(0.14)))
                Text(suggestion.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: severityIcon(suggestion.severity))
                    .font(.caption)
                    .foregroundColor(color)
            }
            Text(suggestion.message)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
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

            Button {
                reminderDraft = ReminderDraft(
                    title: suggestion.title,
                    dueOdometer: suggestion.suggestedIntervalKm.map { vehicle.currentOdometer + $0 },
                    dueInMonths: suggestion.suggestedIntervalMonths
                )
            } label: {
                Label("Hatırlatıcı oluştur", systemImage: "bell.badge")
                    .font(AppTypography.secondaryMedium)
                    .foregroundColor(AppColors.accentPrimary)
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.xxs)
        }
        .padding(AppSpacing.md)
        .padding(.leading, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, AppSpacing.sm)
        }
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var unavailableView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.textTertiary)
            Text("Bulut AI kapalı")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("Kişisel bakım planı için Pro ve bulut AI özelliklerinin açık olması gerekir.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            Button {
                showAIConsent = true
            } label: {
                Text("Bulut AI'yı aç").frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
            .padding(.horizontal, AppSpacing.xxl)
            Spacer()
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(AppColors.textTertiary)
            Text(message)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            Button {
                generate(force: true)
            } label: {
                Text("Tekrar dene").frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
            .padding(.horizontal, AppSpacing.xxl)
            Spacer()
        }
    }

    // MARK: - Logic
    private func loadInitial() {
        guard case .idle = stage else { return }
        // Araç verisi değişmediyse son cache'i kullan; değiştiyse yeniden üret.
        // (force: false → parmak izi karşılaştırması generate içinde yapılır.)
        generate(force: false)
    }

    /// Stage değişimlerini her zaman animasyonlu uygular — idle/loading/loaded/failed
    /// arası geçiş ani bir "pop" yerine yumuşak bir crossfade ile olur.
    private func setStage(_ newStage: Stage) {
        withAnimation(.easeInOut(duration: 0.25)) {
            stage = newStage
        }
    }

    private func generate(force: Bool) {
        // Üç koşul — asla varsayma.
        guard PaywallService.shared.isPro,
              AIConsentStore.shared.isCloudAIEnabled else {
            setStage(.unavailable)
            return
        }

        // Payload'u önden kur (saf, ağ yok) — hem parmak izi hem gönderim için.
        let payload = buildPayload()
        let inputHash = MaintenancePlanCacheStore.fingerprint(payload)

        // Zorlanmadıysa ve cache taze + aynı girdilerle üretilmişse: son cache'i göster.
        // Böylece araç detayında bir değişiklik olmadıkça AI yeniden çağrılmaz
        // (aynı veriyle farklı sonuç riski ortadan kalkar).
        if !force,
           let cached = MaintenancePlanCacheStore.load(vehicleId: vehicle.id),
           MaintenancePlanCacheStore.isFresh(cached),
           cached.inputHash == inputHash {
            suggestions = cached.suggestions
            setStage(.loaded(fromCache: true))
            return
        }

        setStage(.loading)
        Task {
            do {
                let result = try await AIProxyService.shared.maintenancePlan(profileJSON: payload)
                await MainActor.run {
                    suggestions = Array(result.prefix(3))
                    MaintenancePlanCacheStore.save(suggestions, vehicleId: vehicle.id, inputHash: inputHash)
                    setStage(.loaded(fromCache: false))
                }
            } catch let error as AIProxyError {
                await MainActor.run { handleFailure(error) }
            } catch {
                await MainActor.run { setStage(.failed("Plan oluşturulamadı. Daha sonra tekrar dene.")) }
            }
        }
    }

    private func handleFailure(_ error: AIProxyError) {
        // Kural tabanlı öneriler bağımsız çalışmaya devam eder; burada nazikçe degrade.
        switch error {
        case .disabled:
            setStage(.unavailable)
        case .quotaExceeded:
            setStage(.failed("Yapay zekâ ay limitine ulaşıldı. Kural tabanlı öneriler çalışmaya devam ediyor."))
        case .transactionUnavailable:
            setStage(.failed("Etkin Pro satın alımı bulunamadı. Pro durumunu kontrol edip tekrar dene."))
        case .proEntitlementRequired:
            setStage(.failed("Pro satın alımı doğrulanamadı. Satın Almaları Geri Yükle'yi dene."))
        case .unauthorized, .notConfigured:
            setStage(.failed("AI servisi yapılandırması doğrulanamadı."))
        case .transport:
            setStage(.failed("İnternet bağlantısı kurulamadı. Bağlantını kontrol edip tekrar dene."))
        case .payloadTooLarge:
            setStage(.failed("Plan verisi gönderim sınırını aşıyor."))
        case .malformedResponse, .upstream:
            setStage(.failed("Plan oluşturulamadı. Daha sonra tekrar dene."))
        }
    }

    private func buildPayload() -> String {
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
}
