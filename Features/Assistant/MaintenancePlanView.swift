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
    @Query private var allReminders: [Reminder]
    @Query private var allInspectionReports: [InspectionReport]
    @Query private var allExpenses: [Expense]

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

            if let confidence = suggestion.confidence {
                Label(confidenceLabel(confidence), systemImage: "checkmark.shield")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(confidenceColor(confidence))
            }

            Text(suggestion.message)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let evidence = suggestion.evidence, !evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bu sonuca neden ulaştı?")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textPrimary)
                    ForEach(Array(evidence.prefix(3).enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(AppColors.accentPrimary)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            Text(item)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .background(RoundedRectangle(cornerRadius: AppRadius.small).fill(AppColors.backgroundSecondary))
            }

            if let action = suggestion.recommendedAction, !action.isEmpty {
                Label(action, systemImage: "arrow.right.circle")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let limitation = suggestion.limitation, !limitation.isEmpty {
                Label(limitation, systemImage: "info.circle")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
            .sorted {
                $0.date == $1.date
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.date > $1.date
            }
            .prefix(10)
            .map {
                MaintenancePlanPayloadBuilder.ServiceLine(
                    title: $0.serviceType.displayName,
                    date: $0.date,
                    km: $0.odometer,
                    oilType: $0.oilType,
                    notes: $0.notes,
                    nextDueDate: $0.nextReminderDueDate,
                    nextDueOdometer: $0.nextReminderDueOdometer
                )
            }

        let reminders = allReminders
            .filter {
                $0.vehicleId == vehicle.id &&
                $0.statusRaw != ReminderStatus.completed.rawValue &&
                $0.statusRaw != ReminderStatus.archived.rawValue
            }
            .sorted {
                let leftKey = reminderSortKey($0)
                let rightKey = reminderSortKey($1)
                if leftKey != rightKey { return leftKey < rightKey }
                let leftDate = $0.dueDate ?? .distantFuture
                let rightDate = $1.dueDate ?? .distantFuture
                if leftDate != rightDate { return leftDate < rightDate }
                let leftKm = $0.dueOdometer ?? .max
                let rightKm = $1.dueOdometer ?? .max
                return leftKm == rightKm
                    ? $0.id.uuidString < $1.id.uuidString
                    : leftKm < rightKm
            }
            .prefix(8)
            .map {
                MaintenancePlanPayloadBuilder.ReminderLine(
                    title: $0.title,
                    type: $0.type.rawValue,
                    dueDate: $0.dueDate,
                    dueOdometer: $0.dueOdometer,
                    priority: $0.priority.rawValue,
                    state: reminderState($0),
                    notes: $0.notes
                )
            }

        let inspections = allInspectionReports
            .filter { $0.vehicleId == vehicle.id }
            .sorted {
                $0.reportDate == $1.reportDate
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.reportDate > $1.reportDate
            }
            .prefix(3)
            .map {
                MaintenancePlanPayloadBuilder.InspectionLine(
                    date: $0.reportDate,
                    km: $0.odometer,
                    summary: $0.summary,
                    verificationStatus: $0.verificationStatus.rawValue
                )
            }

        let maintenanceCategories: Set<ExpenseCategory> = [
            .service, .oil, .tire, .brake, .battery, .repair, .part,
            .inspection, .emission, .chainSprocket
        ]
        let expenseCutoff = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
        let maintenanceExpenses = allExpenses
            .filter {
                $0.vehicleId == vehicle.id &&
                $0.date >= expenseCutoff &&
                $0.linkedServiceRecordId == nil &&
                maintenanceCategories.contains($0.category)
            }
            .sorted {
                $0.date == $1.date
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.date > $1.date
            }
            .prefix(8)
            .map {
                MaintenancePlanPayloadBuilder.MaintenanceExpenseLine(
                    category: $0.category.rawValue,
                    date: $0.date,
                    km: $0.odometer,
                    note: $0.note
                )
            }

        let input = MaintenancePlanPayloadBuilder.Input(
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year,
            vehicleType: vehicle.vehicleType.rawValue,
            bodyType: vehicle.bodyType,
            engineCC: vehicle.engineCC,
            fuelType: vehicle.fuelType.rawValue,
            transmissionType: vehicle.transmissionType?.rawValue,
            usageType: vehicle.usageType.rawValue,
            odometer: vehicle.currentOdometer,
            odometerIsEstimate: vehicle.odometerIsEstimate,
            odometerUpdatedAt: vehicle.lastOdometerUpdate,
            dailyKmBand: profile?.dailyKmBand.rawValue,
            routeType: profile?.routeType.rawValue,
            fuelConsumptionCity: profile?.fuelConsumptionCity,
            fuelConsumptionHighway: profile?.fuelConsumptionHighway,
            tripTypes: profile?.tripTypes ?? [],
            recentServices: Array(recent),
            activeReminders: Array(reminders),
            recentInspections: Array(inspections),
            recentMaintenanceExpenses: Array(maintenanceExpenses)
        )
        return MaintenancePlanPayloadBuilder.build(input)
    }

    private func reminderState(_ reminder: Reminder) -> String {
        if reminder.isOverdue || reminder.isKmOverdue(vehicleOdometer: vehicle.currentOdometer) {
            return "overdue"
        }
        if reminder.isToday || reminder.isUpcoming || reminder.isKmUpcoming(vehicleOdometer: vehicle.currentOdometer) {
            return "upcoming"
        }
        return "active"
    }

    private func reminderSortKey(_ reminder: Reminder) -> Int {
        switch reminderState(reminder) {
        case "overdue": return 0
        case "upcoming": return 1
        default: return 2
        }
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

    private func confidenceLabel(_ confidence: String) -> String {
        switch confidence {
        case "high": return "Güven düzeyi: yüksek"
        case "medium": return "Güven düzeyi: orta"
        default: return "Güven düzeyi: sınırlı"
        }
    }

    private func confidenceColor(_ confidence: String) -> Color {
        switch confidence {
        case "high": return AppColors.success
        case "medium": return AppColors.warning
        default: return AppColors.textTertiary
        }
    }
}
