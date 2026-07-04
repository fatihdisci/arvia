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
    @State private var showSaleFile = false
    @State private var showAddDocument = false
    @State private var showDocumentPreview = false
    @State private var previewDocumentURL: URL?
    @State private var dismissedGuideInsightIDs: Set<String> = []
    private let snoozeStore = InsightSnoozeStore()

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
            displayContext: .vehicleDetailGuide(excludingReminderIds: Set(upcomingTasks.map(\.reminderId)))
        )
        .filter { !dismissedGuideInsightIDs.contains($0.id) }
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
            VStack(spacing: 28) {
                let fileScore = computeFileScore()

                // MARK: Visual Anchor — Hero Header
                VehicleDetailHero(vehicle: vehicle, fileScore: fileScore)

                if let banner = notificationRouteBanner {
                    banner
                        .padding(.horizontal, AppSpacing.screenMarginH)
                }

                VehicleQuickActionsSection(
                    onKmUpdate: { showQuickKmUpdate = true },
                    onAddExpense: { showAddExpense = true },
                    onAddFuelExpense: { showAddFuelExpense = true },
                    onAddDocument: { showAddDocument = true },
                    onAddReminder: { showAddReminder = true }
                )
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
                InspectionReportSection(inspectionReports: inspectionReports, onAddInspection: handleAddInspection)
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Sale File Preview
                SaleFilePreviewCard(onTap: handleSaleFileTap)
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
                    saleFiles: saleFiles
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
        .sheet(isPresented: $showSaleFile) {
            SaleFileView(vehicle: vehicle)
        }
        .sheet(isPresented: $showAddDocument) {
            DocumentFormView(preselectedVehicleId: vehicle.id)
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
        case .dismissAndSnooze, .markAsRead, .acknowledge, .noAction:
            break // Meta-aksiyonlar — ArviaGuideCard tarafından handle edilir
        }
    }

    private func handleGuideInsightDismiss(_ insight: VehicleInsight) {
        dismissedGuideInsightIDs.insert(insight.id)
        if let days = insight.snoozeDays, days > 0 {
            InsightSnoozeStore.shared.snooze(
                insightType: insight.type,
                forVehicle: vehicle.id,
                days: days
            )
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
