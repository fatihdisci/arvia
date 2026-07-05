import SwiftUI
import SwiftData
import QuickLook

// MARK: - Vehicle Detail View
// Aracın ana dashboard ekranı.
// Tasarım kuralı: Tek görsel çapa (VehicleHeroHeader).
// Kartlar yalnızca anlamlıysa kullanılır — kart mozaik yok.

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var navigationRouter: AppNavigationRouter

    let vehicle: Vehicle

    @Query private var allReminders: [Reminder]
    @Query private var allExpenses: [Expense]
    @Query private var allServiceRecords: [ServiceRecord]
    @Query private var allInspectionReports: [InspectionReport]
    @Query(sort: \VehicleDocument.createdAt, order: .reverse) private var allDocuments: [VehicleDocument]
    @Query(sort: \SaleFile.createdAt, order: .reverse) private var allSaleFiles: [SaleFile]
    @Query private var allUsageProfiles: [VehicleUsageProfile]

    @AppStorage("assistant_profile_prompted") private var assistantProfilePrompted = false

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showArchiveConfirmation = false
    @State private var showAddServiceRecord = false
    @State private var showAddExpense = false
    @State private var showAddFuelExpense = false
    @State private var showAddReminder = false
    @State private var showAddMTVReminder = false
    @State private var showQuickKmUpdate = false
    @State private var showAddInspection = false
    @State private var editingInspectionReport: InspectionReport?
    @State private var showSaleFile = false
    @State private var showAddDocument = false
    @State private var showDocumentPreview = false
    @State private var previewDocumentURL: URL?
    @State private var showReceiptScan = false
    @State private var showReceiptPaywall = false
    @State private var showAssistantProfile = false
    @State private var showMaintenancePlan = false
    @State private var showAssistantPaywall = false
    @State private var showAIConsent = false
    private let snoozeStore = InsightSnoozeStore.shared

    // Filtered data
    private var reminders: [Reminder] {
        allReminders.filter { $0.vehicleId == vehicle.id }
    }

    private var expenses: [Expense] {
        allExpenses.filter { $0.vehicleId == vehicle.id }
    }

    private var serviceRecords: [ServiceRecord] {
        allServiceRecords.filter { $0.vehicleId == vehicle.id }
    }

    private var inspectionReports: [InspectionReport] {
        allInspectionReports.filter { $0.vehicleId == vehicle.id }
            .sorted { $0.reportDate > $1.reportDate }
    }

    private var documents: [VehicleDocument] {
        allDocuments.filter { $0.vehicleId == vehicle.id }
    }

    private var saleFiles: [SaleFile] {
        allSaleFiles.filter { $0.vehicleId == vehicle.id }
    }

    private var recordCounts: RecordCounts {
        RecordCounts(
            bakim: serviceRecords.count,
            masraf: expenses.count,
            belge: documents.count,
            ekspertiz: inspectionReports.count
        )
    }

    private var saleFileReadiness: SaleFileReadiness {
        let total = recordCounts.total
        if total == 0 { return .empty }
        if recordCounts.belge == 0 { return .partial(hasDocuments: false) }
        return .ready
    }

    private var activeReminders: [Reminder] {
        reminders.filter { $0.statusRaw != ReminderStatus.completed.rawValue && $0.statusRaw != ReminderStatus.archived.rawValue }
    }

    // Most critical upcoming task
    private var mostCriticalReminder: Reminder? {
        if let overdue = activeReminders.first(where: { $0.isOverdue }) { return overdue }
        if let today = activeReminders.first(where: { $0.isToday }) { return today }
        return activeReminders
            .filter { $0.dueDate != nil }
            .min(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
    }

    private var guideInsights: [VehicleInsight] {
        VehicleInsightService.shared.insights(
            for: vehicle,
            reminders: reminders,
            expenses: expenses,
            serviceRecords: serviceRecords,
            documents: documents,
            inspectionReports: inspectionReports,
            saleFiles: saleFiles,
            displayContext: .vehicleDetailGuide(excludingReminderIds: Set(upcomingTasks.map(\.reminderId))),
            assistant: assistantInputs
        )
        .filter { !snoozeStore.isDismissed(insightType: $0.type, forVehicle: vehicle.id) }
        .filter { !snoozeStore.isSnoozed(insightType: $0.type, forVehicle: vehicle.id) }
        .filter { !snoozeStore.isSnoozed(vehicleId: vehicle.id, insightId: $0.id) }
    }

    private var upcomingTasks: [VehicleUpcomingTask] {
        VehicleInsightService.shared.upcomingTasks(
            reminders: activeReminders,
            vehicleOdometer: vehicle.currentOdometer
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionGap) {
                let fileScore = computeFileScore()

                // MARK: Visual Anchor — Hero Header
                VehicleDetailHero(vehicle: vehicle)

                if let banner = notificationRouteBanner {
                    banner
                        .padding(.horizontal, AppSpacing.screenMarginH)
                }

                VehicleQuickActionsSection(
                    onKmUpdate: { showQuickKmUpdate = true },
                    onAddExpense: { showAddExpense = true },
                    onAddFuelExpense: { showAddFuelExpense = true },
                    onAddDocument: { showAddDocument = true },
                    onAddReminder: { showAddReminder = true },
                    onScanReceipt: handleScanReceipt
                )
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Kişisel Bakım Planı — Hızlı İşlemler'in hemen altında
                maintenancePlanEntry
                    .padding(.horizontal, AppSpacing.screenMarginH)

                CurrentStatusSection(
                    expenses: expenses,
                    upcomingTasks: upcomingTasks,
                    onAddExpense: { showAddExpense = true }
                )
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: File Completeness
                FileCompletenessCard(vehicle: vehicle, documents: documents, fileScore: fileScore)
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Arvia Rehber
                ArviaGuideSection(
                    insights: guideInsights,
                    vehicleId: vehicle.id,
                    onAction: handleGuideAction,
                    onDismissInsight: handleGuideInsightDismiss
                )
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Inspection Report
                InspectionReportSection(
                    inspectionReports: inspectionReports,
                    onAddInspection: handleAddInspection,
                    onEditReport: handleEditInspection,
                    onDeleteReport: handleDeleteInspection
                )
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Sale File Preview
                SaleFilePreviewCard(
                    readiness: saleFileReadiness,
                    recordCounts: recordCounts,
                    onTap: handleSaleFileTap,
                    onAddExpense: { showAddExpense = true }
                )
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Documents (Belgeler)
                DocumentsSection(
                    documents: documents,
                    previewDocumentURL: $previewDocumentURL,
                    showDocumentPreview: $showDocumentPreview,
                    onAddDocument: { showAddDocument = true }
                )
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Recent Records
                RecentRecordsSection(expenses: expenses, serviceRecords: serviceRecords)

                // MARK: Vehicle Life Timeline
                LifeTimelineSection(
                    vehicle: vehicle,
                    serviceRecords: serviceRecords,
                    expenses: expenses,
                    inspectionReports: inspectionReports,
                    saleFiles: saleFiles,
                    onAddFirstRecord: { showAddExpense = true }
                )

                Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle(vehicle.nickname.isEmpty ? vehicle.fullName : vehicle.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        handleSaleFileTap()
                    } label: {
                        Label("Satış Dosyası", systemImage: "doc.richtext")
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }

                    if vehicle.archivedAt == nil {
                        Button {
                            showArchiveConfirmation = true
                        } label: {
                            Label("Arşivle", systemImage: "archivebox")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Aracı Sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel("Araç İşlemleri")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleEditView(vehicle: vehicle)
        }
        .sheet(isPresented: $showAddServiceRecord) {
            ServiceRecordFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showAddExpense) {
            ExpenseFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showAddFuelExpense) {
            ExpenseFormView(preselectedVehicleId: vehicle.id, preselectedCategory: .fuel)
        }
        .sheet(isPresented: $showAddReminder) {
            ReminderFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showAddMTVReminder) {
            ReminderFormView(
                preselectedVehicleId: vehicle.id,
                preselectedTemplate: Calendar.current.component(.month, from: Date()) == 7 ? .mtvSecond : .mtvFirst
            )
        }
        .sheet(isPresented: $showQuickKmUpdate) {
            QuickOdometerUpdateSheet(vehicle: vehicle)
        }
        .sheet(isPresented: $showAddInspection) {
            InspectionReportFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(item: $editingInspectionReport) { report in
            InspectionReportFormView(existingReport: report)
        }
        .sheet(isPresented: $showSaleFile) {
            SaleFileView(vehicle: vehicle)
        }
        .sheet(isPresented: $showAddDocument) {
            DocumentFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showReceiptScan) {
            ReceiptScanView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showReceiptPaywall) {
            PaywallView(feature: .receiptScan)
                .environmentObject(PaywallService.shared)
        }
        .sheet(isPresented: $showAssistantPaywall) {
            PaywallView(feature: .assistant)
                .environmentObject(PaywallService.shared)
        }
        .sheet(isPresented: $showAssistantProfile) {
            UsageProfileFlowView()
        }
        .sheet(isPresented: $showMaintenancePlan) {
            MaintenancePlanView(vehicle: vehicle)
        }
        .sheet(isPresented: $showAIConsent) {
            AIConsentView(
                onAccept: {
                    UserDefaults.standard.set(true, forKey: AIConsentStore.consentKey)
                    UserDefaults.standard.set(true, forKey: AIConsentStore.enabledKey)
                    showMaintenancePlan = true
                },
                onDecline: {}
            )
        }
        .quickLookPreview($previewDocumentURL)
        .confirmationDialog("Aracı Arşivle", isPresented: $showArchiveConfirmation) {
            Button("Arşivle") { archiveVehicle() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Arşivlenen araç listede görünmez ama verileri silinmez. İstediğin zaman geri alabilirsin.")
        }
        .confirmationDialog("Aracı Sil", isPresented: $showDeleteConfirmation) {
            Button("Aracı ve Tüm Kayıtlarını Sil", role: .destructive) { deleteVehicle() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz. Araca ait tüm hatırlatıcılar, masraflar, bakım kayıtları, belgeler ve ekspertiz raporları kalıcı olarak silinir.")
        }
        .task {
            snoozeStore.removeExpired()
        }
    }



    private func handleScanReceipt() {
        if PaywallService.shared.canUseReceiptScan {
            showReceiptScan = true
        } else {
            showReceiptPaywall = true
        }
    }

    // MARK: - Kişisel Bakım Planı girişi
    private var maintenancePlanEntry: some View {
        let canUse = PaywallService.shared.canUseAssistant
        return Button {
            if canUse {
                // Pro + onay + toggle. Eksikse onay ekranı, tam ise plan.
                if PaywallService.shared.isPro && AIConsentStore.shared.isCloudAIEnabled {
                    showMaintenancePlan = true
                } else {
                    showAIConsent = true
                }
            } else {
                showAssistantPaywall = true
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppColors.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kişisel bakım planı oluştur")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Kullanımına göre yapay zekâ önerileri")
                        .font(AppTypography.bodySecondary)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: canUse ? "chevron.right" : "lock.fill")
                    .font(.caption)
                    .foregroundColor(canUse ? AppColors.textTertiary : AppColors.warning)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).fill(Color.appSurface))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Akıllı Sürüş Asistanı
    private var assistantInputs: VehicleInsightService.AssistantInputs {
        guard PaywallService.shared.canUseAssistant else { return .disabled }
        let profile = UsageProfileService.resolve(for: vehicle.id, from: allUsageProfiles)
        let estimate = PredictiveOdometerService.shared.estimate(
            lastKnownOdometer: vehicle.currentOdometer,
            lastKnownDate: vehicle.odometerIsEstimate ? nil : vehicle.lastOdometerUpdate,
            readings: odometerReadings,
            profileBand: profile?.dailyKmBand
        )
        var suggestion: MaintenanceAdvisorService.Suggestion?
        if let profile {
            let dailyKm = estimate?.dailyKmAverage ?? Double(profile.dailyKmBand.midpointKm)
            suggestion = MaintenanceAdvisorService.shared.topSuggestion(for: MaintenanceAdvisorService.Input(
                fuelType: vehicle.fuelType,
                vehicleYear: vehicle.year,
                currentOdometer: vehicle.currentOdometer,
                dailyKm: dailyKm,
                routeType: profile.routeType,
                dailyKmBand: profile.dailyKmBand,
                now: Date()
            ))
        }
        return VehicleInsightService.AssistantInputs(
            enabled: true,
            odometerEstimate: estimate,
            maintenanceSuggestion: suggestion,
            usageProfileMissing: profile == nil && assistantProfilePrompted
        )
    }

    private var odometerReadings: [PredictiveOdometerService.Reading] {
        var readings: [PredictiveOdometerService.Reading] = []
        for e in expenses where e.odometer != nil { readings.append(.init(date: e.date, odometer: e.odometer!)) }
        for s in serviceRecords where s.odometer != nil { readings.append(.init(date: s.date, odometer: s.odometer!)) }
        return readings
    }

    private func acceptEstimatedOdometer() {
        let profile = UsageProfileService.resolve(for: vehicle.id, from: allUsageProfiles)
        guard let estimate = PredictiveOdometerService.shared.estimate(
            lastKnownOdometer: vehicle.currentOdometer,
            lastKnownDate: vehicle.odometerIsEstimate ? nil : vehicle.lastOdometerUpdate,
            readings: odometerReadings,
            profileBand: profile?.dailyKmBand
        ) else { return }
        Task {
            try? await VehicleContextRefreshService.updateCurrentOdometer(
                vehicle: vehicle,
                newOdometer: estimate.estimatedOdometer,
                isEstimate: true,
                context: modelContext
            )
        }
    }

    private func handleGuideAction(_ action: VehicleInsightAction) {
        switch action {
        case .addServiceRecord:
            showAddServiceRecord = true
        case .addDocument:
            showAddDocument = true
        case .openSaleFile:
            handleSaleFileTap()
        case .updateOdometer:
            showQuickKmUpdate = true
        case .openTodos:
            navigationRouter.selectedTab = .todos
        case .addInspectionReport:
            showAddInspection = true
        case .addReminder:
            showAddReminder = true
        case .addMTVReminder:
            showAddMTVReminder = true
        case .addExpense:
            showAddExpense = true
        case .addFuelExpense:
            showAddFuelExpense = true
        case .acceptEstimatedOdometer:
            acceptEstimatedOdometer()
        case .openAssistantProfile:
            showAssistantProfile = true
        case .dismissAndSnooze, .markAsRead, .acknowledge, .noAction:
            break // Meta-aksiyonlar — ArviaGuideCard tarafından handle edilir
        }
    }

    private func handleGuideInsightDismiss(_ insight: VehicleInsight) {
        snoozeStore.dismiss(insightType: insight.type, forVehicle: vehicle.id)
        if let days = insight.snoozeDays, days > 0 {
            snoozeStore.snooze(insightType: insight.type, forVehicle: vehicle.id, days: days)
        }
        snoozeStore.snooze(vehicleId: vehicle.id, insight: insight)
    }



    // MARK: - Upcoming Task Empty State
    private var notificationRouteBanner: AnyView? {
        guard case let .vehicle(routeVehicleId, focus)? = navigationRouter.pendingNotificationRoute,
              routeVehicleId == vehicle.id else { return nil }

        let title: String
        let message: String
        let icon: String
        let actionTitle: String?
        let action: (() -> Void)?

        switch focus {
        case .kmUpdate:
            title = "Kilometre güncelleme"
            message = "Bu araç için güncel kilometreyi hemen güncelleyebilirsin."
            icon = "gauge.with.needle"
            actionTitle = "Km Güncelle"
            action = { showQuickKmUpdate = true }
        case .fileCompleteness:
            title = "Dosya Skoru"
            message = "Aşağıdaki Dosya Skoru ve Belgeler alanlarından eksik bilgileri tamamlayabilirsin."
            icon = "chart.bar.fill"
            actionTitle = nil
            action = nil
        case .saleFile:
            title = "Satış dosyası"
            message = "Satış dosyası kartından araç bilgilerini ve belgelerini gözden geçirebilirsin."
            icon = "doc.richtext"
            actionTitle = "Satış Dosyası"
            action = { handleSaleFileTap() }
        }

        return AnyView(
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                }
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(RoundedRectangle(cornerRadius: AppRadius.card).fill(AppColors.accentPrimary.opacity(0.08)))
        )
    }


    // MARK: - Upcoming Task Empty State
    private var upcomingTaskEmptyState: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundColor(AppColors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tüm işler tamam")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text("Yaklaşan bir iş görünmüyor.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }


    // MARK: - Score Helpers
    private func computeFileScore() -> Int {
        var score = 0

        // Temel bilgiler (40 puan) — plaka, kimlik, yakıt, satın alma
        if !vehicle.plate.isEmpty { score += 5 }
        if !vehicle.brand.isEmpty { score += 5 }
        if !vehicle.model.isEmpty { score += 5 }
        if vehicle.year != nil { score += 5 }
        if vehicle.currentOdometer > 0 { score += 5 }
        if vehicle.transmissionType != nil { score += 5 }
        if vehicle.vehicleType == .motorcycle, vehicle.engineCC != nil { score += 5 }
        if vehicle.purchaseDate != nil { score += 5 }

        // Araç fotoğrafı (10 puan)
        if vehicle.photoFileName != nil { score += 10 }

        // Belgeler (25 puan) — Dosya Skoru'nun en kritik parçası.
        // Belge olmadan Dosya Skoru %100 olamaz.
        if !documents.isEmpty { score += 15 }
        let uniqueDocTypes = Set(documents.map { $0.type })
        if uniqueDocTypes.count >= 3 { score += 10 }

        // Hatırlatıcı (10 puan)
        if !activeReminders.isEmpty { score += 10 }

        // Masraf + bakım (15 puan)
        if !expenses.isEmpty { score += 8 }
        if !serviceRecords.isEmpty { score += 7 }

        return min(score, 100)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 30 { return AppColors.accentPrimary }
        return AppColors.warning
    }


    // MARK: - Gate Helpers
    private func handleAddInspection() {
        showAddInspection = true
    }

    private func handleEditInspection(_ report: InspectionReport) {
        editingInspectionReport = report
    }

    private func handleDeleteInspection(_ report: InspectionReport) {
        modelContext.delete(report)
        try? modelContext.save()
    }

    private func handleSaleFileTap() {
        showSaleFile = true
    }

    // MARK: - Archive / Delete
    private func archiveVehicle() {
        vehicle.archivedAt = Date()
        try? modelContext.save()
        Task { await NotificationRefreshService.refreshAll(context: modelContext) }
        dismiss()
    }

    private func deleteVehicle() {
        // Önce tüm hatırlatıcı bildirimlerini iptal et
        for reminder in reminders {
            NotificationService.shared.cancelReminder(reminder)
        }

        // Tüm ilişkili verileri sil
        for reminder in reminders { modelContext.delete(reminder) }
        for expense in expenses { modelContext.delete(expense) }
        for service in serviceRecords { modelContext.delete(service) }

        // PartChange'leri sil (serviceRecordId ile bağlı)
        let allParts = (try? modelContext.fetch(FetchDescriptor<PartChange>())) ?? []
        for part in allParts where serviceRecords.contains(where: { $0.id == part.serviceRecordId }) {
            modelContext.delete(part)
        }

        // Belgeleri sil — DB kaydı + fiziksel dosya birlikte temizlenir.
        let allDocs = (try? modelContext.fetch(FetchDescriptor<VehicleDocument>())) ?? []
        for doc in allDocs where doc.vehicleId == vehicle.id {
            try? DocumentStorageService.shared.deleteFile(doc.localFileName)
            modelContext.delete(doc)
        }

        // Ekspertiz raporlarını sil
        let allInspections = (try? modelContext.fetch(FetchDescriptor<InspectionReport>())) ?? []
        for inspection in allInspections where inspection.vehicleId == vehicle.id {
            modelContext.delete(inspection)
        }

        // Satış dosyalarını sil
        let allSales = (try? modelContext.fetch(FetchDescriptor<SaleFile>())) ?? []
        for sale in allSales where sale.vehicleId == vehicle.id {
            modelContext.delete(sale)
        }

        // Araç fotoğrafını fiziksel diskten sil
        if let photoFileName = vehicle.photoFileName {
            VehiclePhotoStorageService.shared.deletePhoto(fileName: photoFileName)
        }

        modelContext.delete(vehicle)
        try? modelContext.save()
        NotificationRefreshService.cancelAllForVehicle(vehicle, context: modelContext)
        Task { await NotificationRefreshService.refreshAll(context: modelContext) }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        dismiss()
    }
}


// MARK: - Vehicle Detail Guide Card
// Faz 1.1: VehicleDetailGuideCard kaldırıldı — yerini VehicleInsightCard aldı.




// MARK: - Preview
#Preview("Araç Detay — Dolu Veri") {
    let vehicle = MockDataProvider.previewVehicle()
    NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
            .environmentObject(AppNavigationRouter.shared)
    }
}

#Preview("Araç Detay — Dark Mode") {
    let vehicle = MockDataProvider.previewVehicle()
    NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
            .environmentObject(AppNavigationRouter.shared)
    }
}

#Preview("Araç Detay — Dinamik Tip") {
    let vehicle = MockDataProvider.previewVehicle()
    NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
            .environmentObject(AppNavigationRouter.shared)
    }
    .environment(\.dynamicTypeSize, .accessibility1)
}
