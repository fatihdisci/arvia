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
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .idle, .loading:
            loadingView
        case .loaded(let fromCache):
            loadedView(fromCache: fromCache)
        case .unavailable:
            unavailableView
        case .failed(let message):
            failedView(message)
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
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if suggestions.isEmpty {
                    Text("Şu an için özel bir öneri yok. Kayıtların arttıkça plan daha isabetli olur.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.screenMarginH)
                } else {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        suggestionCard(suggestion)
                            .padding(.horizontal, AppSpacing.screenMarginH)
                    }
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

    private func suggestionCard(_ suggestion: MaintenancePlanSuggestion) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: severityIcon(suggestion.severity))
                    .foregroundColor(severityColor(suggestion.severity))
                Text(suggestion.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            Text(suggestion.message)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let intervalText = intervalText(suggestion) {
                Text(intervalText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
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
        // Taze yerel kopya varsa kullan (yeniden üretme).
        if let cached = MaintenancePlanCacheStore.load(vehicleId: vehicle.id),
           MaintenancePlanCacheStore.isFresh(cached) {
            suggestions = cached.suggestions
            stage = .loaded(fromCache: true)
            return
        }
        generate(force: false)
    }

    private func generate(force: Bool) {
        // Üç koşul — asla varsayma.
        guard PaywallService.shared.isPro,
              AIConsentStore.shared.isCloudAIEnabled else {
            stage = .unavailable
            return
        }
        if !force,
           let cached = MaintenancePlanCacheStore.load(vehicleId: vehicle.id),
           MaintenancePlanCacheStore.isFresh(cached) {
            suggestions = cached.suggestions
            stage = .loaded(fromCache: true)
            return
        }

        stage = .loading
        let payload = buildPayload()
        Task {
            do {
                let result = try await AIProxyService.shared.maintenancePlan(profileJSON: payload)
                await MainActor.run {
                    suggestions = Array(result.prefix(3))
                    MaintenancePlanCacheStore.save(suggestions, vehicleId: vehicle.id)
                    stage = .loaded(fromCache: false)
                }
            } catch let error as AIProxyError {
                await MainActor.run { handleFailure(error) }
            } catch {
                await MainActor.run { stage = .failed("Plan oluşturulamadı. Daha sonra tekrar dene.") }
            }
        }
    }

    private func handleFailure(_ error: AIProxyError) {
        // Kural tabanlı öneriler bağımsız çalışmaya devam eder; burada nazikçe degrade.
        switch error {
        case .disabled:
            stage = .unavailable
        case .quotaExceeded:
            stage = .failed("Yapay zekâ ay limitine ulaşıldı. Kural tabanlı öneriler çalışmaya devam ediyor.")
        default:
            stage = .failed("Plan oluşturulamadı. Daha sonra tekrar dene.")
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

    private func intervalText(_ s: MaintenancePlanSuggestion) -> String? {
        var parts: [String] = []
        if let km = s.suggestedIntervalKm { parts.append("~\(km.formatted()) km") }
        if let months = s.suggestedIntervalMonths { parts.append("~\(months) ay") }
        return parts.isEmpty ? nil : "Önerilen aralık: " + parts.joined(separator: " / ")
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
