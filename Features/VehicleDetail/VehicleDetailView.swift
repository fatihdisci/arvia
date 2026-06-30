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
    }

    private var upcomingTasks: [VehicleUpcomingTask] {
        VehicleInsightService.shared.upcomingTasks(
            reminders: activeReminders,
            vehicleOdometer: vehicle.currentOdometer
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // MARK: Visual Anchor — Hero Header
                VehicleHeroHeader(vehicle: vehicle)

                if let banner = notificationRouteBanner {
                    banner
                        .padding(.horizontal, AppSpacing.screenMarginH)
                }

                vehicleQuickActionsSection
                    .padding(.horizontal, AppSpacing.screenMarginH)

                monthlySummaryCard
                    .padding(.horizontal, AppSpacing.screenMarginH)

                nextTasksCard
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: File Completeness
                fileCompletenessCard
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Arvia Rehber
                arviaGuideSection
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Inspection Report
                inspectionReportSection
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Sale File Preview
                saleFilePreviewCard
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Documents (Belgeler)
                documentsSection
                    .padding(.horizontal, AppSpacing.screenMarginH)

                // MARK: Recent Records
                recentRecordsSection

                // MARK: Vehicle Life Timeline
                lifeTimelineSection

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
    }

    // MARK: - Arvia Rehber
    private var arviaGuideSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Arvia Rehber")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Aracının kayıtlarına göre bakım, belge ve satış hazırlığı önerileri.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if guideInsights.isEmpty {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.seal")
                        .foregroundColor(AppColors.success)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Şimdilik öne çıkan öneri yok")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Kayıt ekledikçe Arvia Rehber genel önerilerini burada günceller.")
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
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(guideInsights) { insight in
                        ArviaGuideCard(
                            insight: insight,
                            primaryAction: { handleGuideAction(insight.action) },
                            dismissAction: {
                                dismissedGuideInsightIDs.insert(insight.id)
                            }
                        )
                    }
                }
            }

            arviaGuideDisclaimer
        }
    }

    private var arviaGuideDisclaimer: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(AppColors.warning)
                .accessibilityHidden(true)
            Text("Arvia Rehber, araç kayıtlarına göre genel öneriler sunar. Teknik teşhis, ekspertiz veya servis görüşü yerine geçmez.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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
        }
    }

    // MARK: - Daily Quick Actions
    private var vehicleQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Hızlı İşlemler")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("Araç dosyası")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textTertiary)
            }

            QuickActionRail(actions: [
                .init(icon: "gauge.with.needle", label: "Km", color: AppColors.vehicle) {
                    showQuickKmUpdate = true
                },
                .init(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {
                    showAddExpense = true
                },
                .init(icon: "fuelpump", label: "Yakıt", color: AppColors.warning) {
                    showAddFuelExpense = true
                },
                .init(icon: "doc.text.viewfinder", label: "Belge", color: AppColors.document) {
                    showAddDocument = true
                },
                .init(icon: "bell.badge", label: "Hatırlatıcı", color: AppColors.success) {
                    showAddReminder = true
                },
            ], style: .compact)
            .padding(.horizontal, -AppSpacing.screenMarginH)
        }
        .padding(AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColors.backgroundSecondary.opacity(0.48))
        )
    }

    // MARK: - Monthly Summary
    private var monthlySummaryCard: some View {
        let summary = VehicleInsightService.shared.monthlySummary(expenses: expenses)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Bu Ay")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Masraf Ekle") {
                    showAddExpense = true
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
                .frame(minHeight: AppSpacing.minimumTapTarget)
            }

            if summary.isEmpty {
                Text("Bu ay henüz masraf kaydı yok.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(VehicleInsightService.shared.formattedTRY(summary.total))
                            .font(AppTypography.amount)
                            .foregroundColor(AppColors.textPrimary)
                        Text("\(summary.count) masraf kaydı")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    if let topCategory = summary.topCategory {
                        Label(topCategory.displayName, systemImage: topCategory.defaultIcon)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.accentPrimary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.small)
                                    .fill(AppColors.accentPrimary.opacity(0.08))
                            )
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Next Tasks
    private var nextTasksCard: some View {
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Sıradaki İşler")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Tümünü Gör") {
                    navigationRouter.selectedTab = .todos
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
                .frame(minHeight: AppSpacing.minimumTapTarget)
            }

            if upcomingTasks.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(AppColors.success)
                    Text("Yaklaşan bir iş görünmüyor.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .frame(minHeight: AppSpacing.minimumTapTarget)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingTasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(priorityColor(task.priority))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(AppTypography.secondary)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                Text(task.relativeText)
                                    .font(AppTypography.caption)
                                    .foregroundColor(priorityColor(task.priority))
                            }
                            Spacer()
                        }
                        .frame(minHeight: AppSpacing.minimumTapTarget)

                        if index < upcomingTasks.count - 1 {
                            Divider()
                                .padding(.leading, AppSpacing.md)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appSurface,
                            AppColors.warning.opacity(0.055),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .subtleShadow()
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
            title = "Dosya tamlığı"
            message = "Aşağıdaki Dosya Tamlığı ve Belgeler alanlarından eksik bilgileri tamamlayabilirsin."
            icon = "doc.text.magnifyingglass"
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

    private func priorityColor(_ priority: VehicleInsightPriority) -> Color {
        switch priority {
        case .important:
            return AppColors.critical
        case .warning:
            return AppColors.warning
        case .info:
            return AppColors.accentPrimary
        }
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

    // MARK: - File Completeness Card
    private var fileCompletenessCard: some View {
        let score = computeFileScore()

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(scoreColor(score).opacity(0.12), lineWidth: 4)
                        .frame(width: 58, height: 58)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(scoreColor(score).opacity(0.82), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 58, height: 58)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.75), value: score)

                    Text("%\(score)")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Dosya Tamlığı")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(scoreDescription(score))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: AppSpacing.xs) {
                completenessChip(icon: "car.fill", title: vehicle.year == nil ? "Yıl eksik" : "Kimlik tamam", isComplete: vehicle.year != nil)
                completenessChip(icon: "gauge.with.needle", title: vehicle.currentOdometer == 0 ? "Km eksik" : "Km var", isComplete: vehicle.currentOdometer > 0)
                completenessChip(icon: "doc.text", title: documents.isEmpty ? "Belge bekliyor" : "Belge var", isComplete: !documents.isEmpty)
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(scoreColor(score).opacity(0.1), lineWidth: 1)
        )
    }

    private func completenessChip(icon: String, title: String, isComplete: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.captionMedium)
            .foregroundColor(isComplete ? AppColors.success : AppColors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill((isComplete ? AppColors.success : AppColors.textTertiary).opacity(0.075))
            )
    }

    // MARK: - Documents Section (Belgeler)
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Belgeler",
                actionTitle: documents.isEmpty ? nil : "Ekle",
                action: {
                    showAddDocument = true
                }
            )

            if documents.isEmpty {
                Button {
                    showAddDocument = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "doc.text")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Henüz belge yok")
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textPrimary)
                            Text("Belgelerini eklemek için tıkla.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.appSurface)
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(documents.prefix(5)) { doc in
                        documentRow(doc)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.appSurface)
                )

                if documents.count > 5 {
                    Text("+\(documents.count - 5) belge daha")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, AppSpacing.xxs)
                }
            }
        }
    }

    private func documentRow(_ doc: VehicleDocument) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: doc.type.defaultIcon)
                .font(.body)
                .foregroundColor(AppColors.document)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AppSpacing.xxs) {
                    if doc.isExpired {
                        Text("Süresi Geçti")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.critical)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.critical.opacity(0.12))
                            )
                    } else if doc.isExpiringSoon {
                        Text("\(doc.daysUntilExpiry ?? 0) gün")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppColors.warning.opacity(0.12))
                            )
                    }

                    if let size = doc.fileSizeDisplay {
                        Text(size)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }

            Spacer()

            if doc.includeInSaleFile {
                Image(systemName: "doc.richtext.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.accentPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppSpacing.minimumTapTarget)
        .contentShape(Rectangle())
        .onTapGesture {
            previewDocument(doc)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteDocument(doc)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(doc.title.isEmpty ? doc.type.displayName : doc.title)
        .accessibilityHint(doc.isExpired ? "Süresi geçmiş belge" : "Görüntülemek için iki kere dokun")
    }

    private func previewDocument(_ doc: VehicleDocument) {
        let url = DocumentStorageService.shared.fileURL(for: doc.localFileName)
        previewDocumentURL = url
        showDocumentPreview = true
    }

    private func deleteDocument(_ doc: VehicleDocument) {
        try? DocumentStorageService.shared.deleteFile(doc.localFileName)
        modelContext.delete(doc)
        try? modelContext.save()
        Task { await NotificationRefreshService.refreshAll(context: modelContext) }
    }

    // MARK: - Inspection Report Card
    private var inspectionReportSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let latest = inspectionReports.first {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundColor(AppColors.accentPrimary)
                        Text("Ekspertiz Raporu")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        // TODO: Partner doğrulama entegrasyonu geldiğinde badge eklenecek
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(latest.providerName)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textPrimary)
                        if let branch = latest.branchName, !branch.isEmpty {
                            Text(branch)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Text("\(latest.dateDisplay)\(latest.odometerDisplay.map { " · \($0)" } ?? "")")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    if !latest.summary.isEmpty {
                        Text(latest.summary)
                            .font(AppTypography.secondarySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(3)
                    }

                    // Hukuki uyarı
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                        Text(InspectionReport.legalDisclaimer)
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(2)
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .subtleShadow()
            } else {
                // Ekspertiz yok — ekleme çağrısı
                Button {
                    handleAddInspection()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ekspertiz raporu ekle")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.accentPrimary)
                            Text("Aracının ekspertiz raporunu ekleyerek satış dosyanı güçlendir.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(Color.appSurface)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Sale File Preview Card
    /// Satış Dosyası önizleme kartı.
    /// Güvenli dil: Mekanik/hukuki garanti ima etmez.
    private var saleFilePreviewCard: some View {
        Button {
            handleSaleFileTap()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.success.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.richtext")
                        .font(.title3)
                        .foregroundColor(AppColors.success)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Satış Dosyası")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Bakım, belge ve ekspertiz kayıtlarından güven dosyası oluştur.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(Color.appSurface)
            )
            .subtleShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Satış Dosyası — Bakım, belge ve ekspertiz kayıtlarından güven dosyası oluştur.")
        .accessibilityHint("Satış dosyası oluşturmak için çift tıkla")
    }

    // MARK: - Recent Records Section
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(
                title: "Son Kayıtlar",
                actionTitle: expenses.isEmpty && serviceRecords.isEmpty ? nil : "Tümü",
                action: {}
            )

            if expenses.isEmpty && serviceRecords.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                    Text("Henüz kayıt yok. Masraf veya bakım ekleyerek başlayabilirsin.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.appSurface)
                )
                .padding(.horizontal, AppSpacing.screenMarginH)
            } else {
                // Son 3 kayıt (masraf + bakım karışık, tarihe göre)
                let recentItems = recentRecords()
                ForEach(recentItems.prefix(3)) { item in
                    recentRecordRow(item)
                }
            }
        }
    }

    private func recentRecords() -> [RecentRecordItem] {
        var items: [RecentRecordItem] = []

        for expense in expenses {
            items.append(RecentRecordItem(
                id: expense.id,
                type: .expense,
                title: expense.category.displayName,
                subtitle: expense.amountCompactDisplay,
                date: expense.date,
                icon: expense.category.defaultIcon
            ))
        }

        for service in serviceRecords {
            items.append(RecentRecordItem(
                id: service.id,
                type: .service,
                title: service.serviceType.displayName,
                subtitle: service.vendorName ?? service.totalCostDisplay ?? "",
                date: service.date,
                icon: "wrench.and.screwdriver"
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private func recentRecordRow(_ item: RecentRecordItem) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                Text(item.subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(item.date.formatted(date: .numeric, time: .omitted))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Vehicle Life Timeline
    // Aracın kronolojik yaşam çizgisi — uygulamanın imza etkileşimi.
    private var lifeTimelineSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Araç Yaşam Çizgisi")

            VStack(spacing: AppSpacing.xs) {
                let allEvents = buildTimelineEvents()
                let events = Array(allEvents.suffix(8))
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    timelineItem(
                        event: event,
                        isFirst: index == 0,
                        isLast: index == events.count - 1
                    )
                }

                if allEvents.count > events.count {
                    Text("En güncel \(events.count) kayıt gösteriliyor.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.xs)
                }

                if events.isEmpty {
                    timelineItem(
                        event: TimelineEvent(
                            id: UUID(),
                            icon: "car",
                            title: "Henüz kayıt yok",
                            date: nil,
                            isMilestone: false,
                            subtitle: nil
                        ),
                        isFirst: true,
                        isLast: true
                    )
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColors.backgroundSecondary.opacity(0.52))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.border.opacity(0.6), lineWidth: 1)
            )
            .padding(.horizontal, AppSpacing.screenMarginH)

            if serviceRecords.isEmpty {
                Text("Bakım ve masraf kayıtlarını ekledikçe aracının yaşam çizgisi burada şekillenecek.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.screenMarginH + AppSpacing.md)
            }
        }
    }

    private struct TimelineEvent: Identifiable {
        let id: UUID
        let icon: String
        let title: String
        let date: Date?
        let isMilestone: Bool
        let subtitle: String?
    }

    private func buildTimelineEvents() -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        // Satın alma
        if let purchaseDate = vehicle.purchaseDate {
            events.append(TimelineEvent(
                id: UUID(),
                icon: "cart",
                title: "Satın Alma",
                date: purchaseDate,
                isMilestone: true,
                subtitle: vehicle.purchasePriceDisplay
            ))
        }

        // Kilometre taşları — servis kayıtları (tarihe göre eskiden yeniye)
        let sortedServices = serviceRecords.sorted { ($0.date) < ($1.date) }
        for service in sortedServices.prefix(10) {
            events.append(TimelineEvent(
                id: service.id,
                icon: "wrench.and.screwdriver",
                title: service.serviceType.displayName,
                date: service.date,
                isMilestone: false,
                subtitle: service.vendorName ?? service.totalCostDisplay
            ))
        }

        // Önemli masraflar (büyük tutarlı, sadece 1000₺ üzeri)
        let majorExpenses = expenses
            .filter { $0.amount >= 1000 }
            .sorted { $0.date < $1.date }
            .prefix(5)
        for expense in majorExpenses {
            events.append(TimelineEvent(
                id: expense.id,
                icon: expense.category.defaultIcon,
                title: expense.category.displayName,
                date: expense.date,
                isMilestone: false,
                subtitle: expense.amountCompactDisplay
            ))
        }

        // Tarihe göre sırala (eskiden yeniye)
        events.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        return events
    }

    private func timelineItem(
        event: TimelineEvent,
        isFirst: Bool,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(event.isMilestone ? AppColors.accentPrimary.opacity(0.3) : AppColors.border)
                        .frame(width: 2, height: 14)
                } else {
                    Spacer().frame(height: 4)
                }

                Image(systemName: event.icon)
                    .font(.system(size: event.isMilestone ? 12 : 10, weight: .semibold))
                    .foregroundColor(event.isMilestone ? .white : AppColors.textSecondary)
                    .frame(width: event.isMilestone ? 28 : 24, height: event.isMilestone ? 28 : 24)
                    .background(
                        Circle()
                            .fill(event.isMilestone ? AppColors.accentPrimary : Color.appSurface)
                    )
                    .overlay(
                        Circle()
                            .stroke(event.isMilestone ? AppColors.accentPrimary.opacity(0.24) : AppColors.border.opacity(0.8), lineWidth: 1)
                    )

                if !isLast {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(width: 2, height: 14)
                } else {
                    Spacer().frame(height: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(event.isMilestone ? AppTypography.bodyMedium : AppTypography.secondary)
                    .foregroundColor(event.isMilestone ? AppColors.accentPrimary : AppColors.textPrimary)

                if let subtitle = event.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let date = event.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()
        }
        .frame(minHeight: AppSpacing.minimumTapTarget)
    }

    // MARK: - Score Helpers
    private func computeFileScore() -> Int {
        var score = 0
        if !vehicle.brand.isEmpty { score += 10 }
        if !vehicle.model.isEmpty { score += 10 }
        if vehicle.year != nil { score += 10 }
        if vehicle.currentOdometer > 0 { score += 10 }
        if vehicle.transmissionType != nil { score += 10 }
        if vehicle.purchaseDate != nil { score += 10 }
        if vehicle.purchasePrice != nil { score += 10 }
        if vehicle.vehicleType == .motorcycle, vehicle.engineCC != nil { score += 10 }
        if !reminders.isEmpty { score += 15 }
        if !activeReminders.contains(where: { $0.isOverdue }) { score += 15 }
        if !expenses.isEmpty { score += 5 }
        if !serviceRecords.isEmpty { score += 5 }
        return min(score, 100)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return AppColors.success }
        if score >= 50 { return AppColors.warning }
        return AppColors.critical
    }

    private func scoreDescription(_ score: Int) -> String {
        if score >= 80 { return "Aracının dosyası oldukça tam." }
        if score >= 50 { return "Birkaç bilgi daha ekleyebilirsin." }
        return "Dosyanı tamamlamak için bilgi ekle."
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

// MARK: - Upcoming Task Card
struct UpcomingTaskCard: View {
    let reminder: Reminder

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // İkon
            Image(systemName: reminder.type.defaultIcon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(statusColor.opacity(0.12))
                )

            // İçerik
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(statusColor)

                Text(reminder.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                if let dueDate = reminder.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            // Kalan gün
            if reminder.isOverdue {
                Text("\(reminder.daysOverdue) gün")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.critical)
            } else if reminder.isToday {
                Text("Bugün")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.warning)
            } else {
                Text("\(reminder.daysRemaining) gün")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusTitle): \(reminder.title), \(statusText)")
    }

    private var statusColor: Color {
        if reminder.isOverdue { return AppColors.critical }
        if reminder.isToday { return AppColors.warning }
        return AppColors.accentPrimary
    }

    private var statusTitle: String {
        if reminder.isOverdue { return "Gecikmiş İş" }
        if reminder.isToday { return "Bugün" }
        return "Yaklaşan İş"
    }

    private var statusText: String {
        if reminder.isOverdue { return "\(reminder.daysOverdue) gün gecikti" }
        if reminder.isToday { return "Bugün" }
        return "\(reminder.daysRemaining) gün kaldı"
    }
}

// MARK: - Contextual Insight Compact Card
struct ContextualInsightCompactCard: View {
    let insight: VehicleInsight
    var prominence: Prominence = .secondary
    let action: () -> Void

    enum Prominence {
        case primary
        case secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: prominence == .primary ? AppSpacing.md : AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(prominence == .primary ? .title3 : .body)
                    .foregroundColor(color)
                    .frame(width: prominence == .primary ? 42 : 32, height: prominence == .primary ? 42 : 32)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(color.opacity(prominence == .primary ? 0.15 : 0.1))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title)
                        .font(prominence == .primary ? AppTypography.cardTitle : AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.body)
                        .font(prominence == .primary ? AppTypography.secondarySmall : AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                action()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(insight.action.title)
                        .font(AppTypography.captionMedium)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(prominence == .primary ? AppColors.textOnAccent : AppColors.accentPrimary)
                .padding(.horizontal, prominence == .primary ? AppSpacing.sm : 0)
                .frame(minHeight: AppSpacing.minimumTapTarget, alignment: .leading)
                .background(
                    Capsule()
                        .fill(prominence == .primary ? color : Color.clear)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(prominence == .primary ? AppSpacing.md : AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: prominence == .primary ? AppRadius.heroCard : AppRadius.card)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: prominence == .primary ? AppRadius.heroCard : AppRadius.card)
                .stroke(color.opacity(prominence == .primary ? 0.2 : 0.12), lineWidth: 1)
        )
        .subtleShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.body). \(insight.action.title)")
    }

    private var backgroundFill: LinearGradient {
        LinearGradient(
            colors: prominence == .primary
                ? [Color.appSurface, color.opacity(0.095)]
                : [Color.appSurface, AppColors.backgroundSecondary.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var color: Color {
        switch insight.priority {
        case .important:
            return AppColors.critical
        case .warning:
            return AppColors.warning
        case .info:
            return AppColors.accentPrimary
        }
    }

    private var icon: String {
        switch insight.type {
        case .overdueReminder:
            return "exclamationmark.triangle.fill"
        case .upcomingReminder:
            return "bell.badge"
        case .calendarPeriod:
            return "calendar.badge.clock"
        case .odometerUpdate:
            return "gauge.with.needle"
        case .seasonalGuidance:
            return "sun.max"
        case .missingDocument:
            return "doc.text"
        case .monthlyExpensePrompt:
            return "turkishlirasign.circle"
        case .fuelTypeGuidance:
            return "fuelpump"
        case .transmissionGuidance:
            return "gearshape.2"
        case .odometerMilestone:
            return "flag.checkered"
        case .maintenance:
            return "wrench.and.screwdriver"
        case .quietGoodState:
            return "checkmark.seal"
        case .saleFileReadiness:
            return "doc.richtext"
        }
    }
}

// MARK: - Quick Odometer Update Sheet
struct QuickOdometerUpdateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle

    @State private var odometerText: String
    @State private var errorMessage: String?
    @State private var showLowerConfirmation = false
    @State private var pendingLowerValue: Int?
    @FocusState private var isInputFocused: Bool

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _odometerText = State(initialValue: vehicle.currentOdometer > 0 ? String(vehicle.currentOdometer) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Mevcut km")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(vehicle.odometerDisplay)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "gauge.with.needle")
                            .foregroundColor(AppColors.textTertiary)
                        TextField("Yeni km", text: $odometerText)
                            .keyboardType(.numberPad)
                            .focused($isInputFocused)
                    }
                } footer: {
                    Text("Güncel kilometre, bakım ve masraf takibini daha doğru hale getirir.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .listRowBackground(Color.appSurface)

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.critical)
                    }
                    .listRowBackground(AppColors.criticalBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Kilometreyi Güncelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: validateAndSave)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
            .onAppear {
                isInputFocused = true
            }
            .confirmationDialog("Daha düşük km kaydedilsin mi?", isPresented: $showLowerConfirmation) {
                Button("Daha düşük km ile kaydet") {
                    if let pendingLowerValue {
                        save(pendingLowerValue)
                    }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Yeni km mevcut km'den düşük. Bunu yalnızca önceki kaydı düzeltmek istiyorsan onayla.")
            }
        }
    }

    private func validateAndSave() {
        errorMessage = nil
        let result = VehicleInsightService.shared.validateOdometerInput(
            odometerText,
            currentOdometer: vehicle.currentOdometer,
            allowLowerValue: false
        )

        switch result {
        case .valid:
            if let value = VehicleInsightService.shared.parsedOdometer(odometerText) {
                save(value)
            }
        case .empty:
            errorMessage = "Yeni kilometre değerini girmelisin."
        case .invalid:
            errorMessage = "Geçerli bir kilometre değeri girmelisin."
        case .negative:
            errorMessage = "Km sıfırdan küçük olamaz."
        case .lowerNeedsConfirmation:
            pendingLowerValue = VehicleInsightService.shared.parsedOdometer(odometerText)
            showLowerConfirmation = true
        }
    }

    private func save(_ value: Int) {
        Task {
            do {
                try await VehicleContextRefreshService.updateCurrentOdometer(
                    vehicle: vehicle,
                    newOdometer: value,
                    context: modelContext
                )
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = "Kaydedilemedi: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Recent Record Item
struct RecentRecordItem: Identifiable {
    let id: UUID
    let type: RecordType
    let title: String
    let subtitle: String
    let date: Date
    let icon: String

    enum RecordType {
        case expense
        case service
    }
}

// MARK: - Preview
#Preview("Araç Detay — Dolu Veri") {
    let vehicle = MockDataProvider.previewVehicle()
    return NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
    }
}

#Preview("Araç Detay — Dark Mode") {
    let vehicle = MockDataProvider.previewVehicle()
    return NavigationStack {
        VehicleDetailView(vehicle: vehicle)
            .modelContainer(MockDataProvider.previewContainer)
    }
    .preferredColorScheme(.dark)
}
