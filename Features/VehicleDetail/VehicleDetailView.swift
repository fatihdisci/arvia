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
                // MARK: Visual Anchor — Hero Header
                vehicleDetailHero

                if let banner = notificationRouteBanner {
                    banner
                        .padding(.horizontal, AppSpacing.screenMarginH)
                }

                vehicleQuickActionsSection
                    .padding(.horizontal, AppSpacing.screenMarginH)

                currentStatusSection
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
        .task {
            snoozeStore.removeExpired()
        }
    }

    // MARK: - Detail Hero
    private var vehicleDetailHero: some View {
        VStack(spacing: AppSpacing.md) {
            detailHeroPhotoCard
            detailHeroInfoCard
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vehicle.plate), \(vehicle.fullName), \(vehicle.odometerDisplay)")
    }

    private var detailHeroPhotoCard: some View {
        ZStack {
            if let photoFileName = vehicle.photoFileName,
               let image = VehiclePhotoStorageService.shared.loadPhoto(fileName: photoFileName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            AppColors.vehicle.opacity(0.92),
                            AppColors.vehicle.opacity(0.7),
                            AppColors.accentPrimary.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: vehicle.vehicleType.heroSymbol)
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.32))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var detailHeroInfoCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Satır 1: kimlik (fullName/nickname + plaka yan yana)
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.nickname.isEmpty ? vehicle.fullName : vehicle.nickname)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if !vehicle.nickname.isEmpty {
                        Text(vehicle.fullName)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Text(vehicle.yearDisplay)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                        Text("•")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                        Text(vehicle.vehicleType.displayName)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: AppSpacing.sm)

                detailPlateBadge
            }

            Divider()

            // Satır 2: metrics
            HStack(spacing: AppSpacing.xs) {
                detailMetricBadge(icon: "gauge.with.needle", text: vehicle.odometerDisplay)
                detailMetricBadge(icon: "fuelpump", text: vehicle.fuelType.displayName)
                if let transmission = vehicle.transmissionType {
                    detailMetricBadge(
                        icon: transmission == .automatic ? "a.circle" : "m.circle",
                        text: transmission.displayName
                    )
                }
                Spacer(minLength: 0)
            }

            // Satır 3: dosya tamlığı
            detailDossierBadge
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.heroCard, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
    }

    private var detailPlateBadge: some View {
        Text(vehicle.plate.isEmpty ? "Plaka yok" : vehicle.plate)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundColor(AppColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColors.backgroundSecondary.opacity(0.72)))
    }

    private var detailYearTypeBlock: some View {
        HStack(spacing: 3) {
            Text(vehicle.yearDisplay)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textPrimary)
            Text("•")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
            Text(vehicle.vehicleType.displayName)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private var detailDossierBadge: some View {
        let score = computeFileScore()
        let barColor = score >= 80 ? AppColors.success : AppColors.accentPrimary
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundColor(barColor)
                Text("Dosya Skoru")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                Spacer(minLength: 0)
                Text("%\(score)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(6, geo.size.width * CGFloat(score) / 100.0), height: 6)
                        .animation(.easeOut(duration: 0.7), value: score)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(barColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .stroke(barColor.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityLabel("Dosya skoru yüzde \(score)")
    }

    private func detailMetricBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.medium))
            Text(text)
                .font(AppTypography.captionMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs + 2)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(AppColors.backgroundSecondary.opacity(0.68))
        )
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
                        .font(.body)
                        .foregroundColor(AppColors.success.opacity(0.7))
                        .frame(width: 24)
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
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
                )
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(guideInsights.prefix(3)) { insight in
                        VehicleDetailGuideCard(
                            insight: insight,
                            primaryAction: { handleGuideAction(insight.action) },
                            dismissAction: {
                                dismissedGuideInsightIDs.insert(insight.id)
                                snoozeStore.snooze(vehicleId: vehicle.id, insight: insight)
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
                .font(.caption2)
                .foregroundColor(AppColors.textTertiary)
                .accessibilityHidden(true)
            Text("Arvia Rehber, araç kayıtlarına göre genel öneriler sunar.")
                .font(.system(size: 11))
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
            Text("Hızlı İşlemler")
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                vehicleDetailActionButton(icon: "gauge.with.needle", label: "Km", color: AppColors.vehicle) {
                    showQuickKmUpdate = true
                }
                vehicleDetailActionButton(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {
                    showAddExpense = true
                }
                vehicleDetailActionButton(icon: "fuelpump", label: "Yakıt", color: AppColors.warning) {
                    showAddFuelExpense = true
                }
                vehicleDetailActionButton(icon: "doc.text.viewfinder", label: "Belge", color: AppColors.document) {
                    showAddDocument = true
                }
                vehicleDetailActionButton(icon: "bell.badge", label: "Hatırlatıcı", color: AppColors.success) {
                    showAddReminder = true
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
    }

    private func vehicleDetailActionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppColors.backgroundSecondary.opacity(0.65))
            )
        }
        .buttonStyle(PlainCardButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: - Current Status
    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Güncel Durum")
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: AppSpacing.sm) {
                monthlySummaryCard
                nextTasksCard
            }
        }
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
                VStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "turkishlirasign.circle")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary.opacity(0.6))
                        Text("Bu ay henüz masraf kaydı yok.")
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(VehicleInsightService.shared.formattedTRY(summary.total))
                            .font(AppTypography.amount)
                            .foregroundColor(AppColors.textPrimary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.accentPrimary.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text("\(summary.count) masraf kaydı")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
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
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(AppColors.success.opacity(0.7))
                    Text("Yaklaşan bir iş görünmüyor.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .frame(minHeight: AppSpacing.minimumTapTarget)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingTasks.prefix(4).enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: AppSpacing.sm) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(priorityColor(task.priority))
                                .frame(width: 4, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(AppTypography.secondaryMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    if task.priority == .important {
                                        Text("Gecikti")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(AppColors.critical)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(
                                                Capsule()
                                                    .fill(AppColors.critical.opacity(0.1))
                                            )
                                    } else {
                                        Text(task.relativeText)
                                            .font(AppTypography.caption)
                                            .foregroundColor(priorityColor(task.priority))
                                    }
                                }
                            }

                            Spacer()
                        }
                        .frame(minHeight: AppSpacing.minimumTapTarget)

                        if index < min(upcomingTasks.count, 4) - 1 {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
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

    // MARK: - File Score Card
    private var fileCompletenessCard: some View {
        let score = computeFileScore()

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(AppColors.border.opacity(0.70), lineWidth: 3.5)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(AppColors.accentPrimary.opacity(0.75), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: score)

                    Text("%\(score)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Dosya Skoru")
                        .font(AppTypography.cardTitle)
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
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
        )
    }

    private func completenessChip(icon: String, title: String, isComplete: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.captionMedium)
            .foregroundColor(isComplete ? AppColors.textSecondary : AppColors.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, AppSpacing.xs + 2)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill((isComplete ? AppColors.accentPrimary : AppColors.textTertiary).opacity(0.07))
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
                let recentItems = recentRecords()
                VStack(spacing: AppSpacing.xs) {
                    ForEach(recentItems.prefix(3)) { item in
                        recentRecordRow(item)
                    }
                }
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .fill(Color.appSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
                )
                .padding(.horizontal, AppSpacing.screenMarginH)
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
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(AppColors.accentPrimary.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(item.title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.date.formatted(date: .numeric, time: .omitted))
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textTertiary)
                .monospacedDigit()
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColors.backgroundSecondary.opacity(0.42))
        )
    }

    // MARK: - Vehicle Life Timeline
    // Aracın kronolojik yaşam çizgisi — uygulamanın imza etkileşimi.
    // Karar 3.3: Milestone event'ler ayrıcalıklı kart olarak gösterilir,
    // regular event'ler mevcut sade liste halini korur.
    private var lifeTimelineSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Araç Yaşam Çizgisi")

            VStack(spacing: AppSpacing.md) {
                let allEvents = buildTimelineEvents()
                let milestoneEvents = allEvents.filter { $0.isMilestone }
                let regularEvents = allEvents.filter { !$0.isMilestone }
                let recentRegulars = Array(regularEvents.suffix(8))

                // Milestone kartları — her biri için VehicleDetailMilestoneCard
                ForEach(Array(milestoneEvents.enumerated()), id: \.element.id) { index, milestone in
                    if let kind = milestone.milestoneKind,
                       let date = milestone.date,
                       let accent = milestone.accent {
                        VehicleDetailMilestoneCard(
                            kind: kind,
                            date: date,
                            title: milestone.title,
                            subtitle: milestone.subtitle,
                            icon: milestone.icon,
                            accent: accent
                        )
                        if index < milestoneEvents.count - 1 {
                            Divider()
                                .padding(.vertical, AppSpacing.xxs)
                                .opacity(0.5)
                        }
                    }
                }

                // Milestone'lar ile regular'lar arasında ayraç
                if !milestoneEvents.isEmpty && !recentRegulars.isEmpty {
                    Divider()
                        .padding(.vertical, AppSpacing.xxs)
                }

                // Regular timeline items (sade liste)
                ForEach(Array(recentRegulars.enumerated()), id: \.element.id) { index, event in
                    timelineItem(
                        event: event,
                        isFirst: index == 0,
                        isLast: index == recentRegulars.count - 1
                    )
                }

                // Eski kayıt uyarısı
                if regularEvents.count > recentRegulars.count {
                    Text("\(regularEvents.count - recentRegulars.count) eski kayıt gösterilmiyor.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.xs)
                }

                // Empty state
                if milestoneEvents.isEmpty && recentRegulars.isEmpty {
                    timelineItem(
                        event: TimelineEvent(
                            id: UUID(),
                            icon: "car",
                            title: "Henüz kayıt yok",
                            date: nil,
                            isMilestone: false,
                            milestoneKind: nil,
                            subtitle: nil,
                            accent: nil
                        ),
                        isFirst: true,
                        isLast: true
                    )
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border.opacity(0.85), lineWidth: 0.5)
            )
            .padding(.horizontal, AppSpacing.screenMarginH)

            if serviceRecords.isEmpty && inspectionReports.isEmpty {
                Text("Bakım, masraf ve ekspertiz kayıtlarını ekledikçe aracının yaşam çizgisi burada şekillenecek.")
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
        let milestoneKind: VehicleDetailMilestoneCard.MilestoneKind?
        let subtitle: String?
        let accent: Color?
    }

    private func buildTimelineEvents() -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        // Satın alma — milestone
        if let purchaseDate = vehicle.purchaseDate {
            events.append(TimelineEvent(
                id: UUID(),
                icon: "cart.fill",
                title: "Satın Alma",
                date: purchaseDate,
                isMilestone: true,
                milestoneKind: .purchase,
                subtitle: vehicle.purchasePriceDisplay,
                accent: VehicleDetailMilestoneCard.MilestoneKind.purchase.defaultAccent
            ))
        }

        // Sahiplik yıl dönümü — 5+ yıl ise milestone
        if let purchaseDate = vehicle.purchaseDate {
            let yearsOwned = Calendar.current.dateComponents([.year], from: purchaseDate, to: Date()).year ?? 0
            if yearsOwned >= 5 {
                let milestoneDate = Calendar.current.date(byAdding: .year, value: 5, to: purchaseDate) ?? purchaseDate
                events.append(TimelineEvent(
                    id: UUID(),
                    icon: "flag.checkered",
                    title: "\(yearsOwned). Yıl — Sahiplik Dönüm Noktası",
                    date: milestoneDate,
                    isMilestone: true,
                    milestoneKind: .ownershipYear,
                    subtitle: "Bu araç \(yearsOwned) yıldır seninle.",
                    accent: VehicleDetailMilestoneCard.MilestoneKind.ownershipYear.defaultAccent
                ))
            }
        }

        // İlk büyük bakım — parts_cost > 5000 veya service_type = major
        // (ServiceType enum'unda .major yok; aşağıdaki set major işlem kapsamında değerlendirilir)
        let majorServiceTypes: Set<ServiceType> = [.engine, .transmission, .body, .airConditioning]
        let sortedServices = serviceRecords.sorted { ($0.date) < ($1.date) }
        for service in sortedServices {
            let isMajor = (service.partsCost ?? 0) > 5000
                || (service.totalCost ?? 0) > 7000
                || majorServiceTypes.contains(service.serviceType)
            if isMajor {
                events.append(TimelineEvent(
                    id: UUID(),
                    icon: "wrench.and.screwdriver.fill",
                    title: service.serviceType.displayName,
                    date: service.date,
                    isMilestone: true,
                    milestoneKind: .majorService,
                    subtitle: service.vendorName ?? service.totalCostDisplay,
                    accent: VehicleDetailMilestoneCard.MilestoneKind.majorService.defaultAccent
                ))
            }
        }

        // Diğer bakım kayıtları (major olmayanlar) — regular timeline item
        for service in sortedServices.prefix(10) {
            let isMajor = (service.partsCost ?? 0) > 5000
                || (service.totalCost ?? 0) > 7000
                || majorServiceTypes.contains(service.serviceType)
            if isMajor { continue } // zaten milestone olarak eklendi
            events.append(TimelineEvent(
                id: service.id,
                icon: "wrench.and.screwdriver",
                title: service.serviceType.displayName,
                date: service.date,
                isMilestone: false,
                milestoneKind: nil,
                subtitle: service.vendorName ?? service.totalCostDisplay,
                accent: nil
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
                milestoneKind: nil,
                subtitle: expense.amountCompactDisplay,
                accent: nil
            ))
        }

        // Ekspertiz raporları — her biri milestone
        for inspection in inspectionReports {
            events.append(TimelineEvent(
                id: UUID(),
                icon: "checkmark.seal.fill",
                title: inspection.providerName,
                date: inspection.reportDate,
                isMilestone: true,
                milestoneKind: .inspection,
                subtitle: inspection.branchName,
                accent: VehicleDetailMilestoneCard.MilestoneKind.inspection.defaultAccent
            ))
        }

        // Satış dosyaları — ilki milestone
        if let firstSale = saleFiles.sorted(by: { ($0.createdAt) < ($1.createdAt) }).first {
            events.append(TimelineEvent(
                id: UUID(),
                icon: "doc.richtext.fill",
                title: firstSale.title.isEmpty ? "Satış Dosyası" : firstSale.title,
                date: firstSale.createdAt,
                isMilestone: true,
                milestoneKind: .saleFile,
                subtitle: "Alıcı ile paylaşım için hazırlandı.",
                accent: VehicleDetailMilestoneCard.MilestoneKind.saleFile.defaultAccent
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
                        .fill(event.isMilestone ? AppColors.accentPrimary.opacity(0.28) : AppColors.border.opacity(0.72))
                        .frame(width: 1.5, height: 12)
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
                        .fill(AppColors.border.opacity(0.72))
                        .frame(width: 1.5, height: 16)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(width: 30)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(event.isMilestone ? AppTypography.bodyMedium : AppTypography.secondary)
                        .foregroundColor(event.isMilestone ? AppColors.accentPrimary : AppColors.textPrimary)
                        .lineLimit(2)

                    if let subtitle = event.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: AppSpacing.xs)

                if let date = event.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                        .monospacedDigit()
                }
            }
        }
        .padding(AppSpacing.xs)
        .frame(minHeight: AppSpacing.minimumTapTarget)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(event.isMilestone ? AppColors.accentPrimary.opacity(0.055) : AppColors.backgroundSecondary.opacity(0.35))
        )
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
        if score >= 50 { return AppColors.warning }
        return AppColors.critical
    }

    private func scoreDescription(_ score: Int) -> String {
        if score >= 80 { return "Aracının geçmişi iyi dokümante edilmiş." }
        if score >= 50 { return "Birkaç bilgi veya belge daha ekleyebilirsin." }
        return "Skoru yükseltmek için bilgi, hatırlatıcı ve belge ekle."
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
                        Text("Mevcut km").foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(vehicle.odometerDisplay).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary)
                    }
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "gauge.with.needle").foregroundColor(AppColors.textTertiary)
                        TextField("Yeni km", text: $odometerText).keyboardType(.decimalPad).focused($isInputFocused)
                    }
                } footer: {
                    Text("Güncel kilometre, bakım ve masraf takibini daha doğru hale getirir.")
                        .font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                }
                .listRowBackground(Color.appSurface)
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.secondary).foregroundColor(AppColors.critical)
                    }
                    .listRowBackground(AppColors.criticalBackground)
                }
            }
            .scrollContentBackground(.hidden).background(Color.appBackground)
            .navigationTitle("Kilometreyi Güncelle").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.foregroundColor(AppColors.textSecondary) }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet", action: validateAndSave).font(AppTypography.bodyMedium).foregroundColor(AppColors.accentPrimary) }
            }
            .onAppear { isInputFocused = true }
            .confirmationDialog("Daha düşük km kaydedilsin mi?", isPresented: $showLowerConfirmation) {
                Button("Daha düşük km ile kaydet") { if let pendingLowerValue { save(pendingLowerValue) } }
                Button("İptal", role: .cancel) {}
            } message: { Text("Yeni km mevcut km'den düşük. Bunu yalnızca önceki kaydı düzeltmek istiyorsan onayla.") }
        }
    }
    private func validateAndSave() {
        errorMessage = nil
        let result = VehicleInsightService.shared.validateOdometerInput(odometerText, currentOdometer: vehicle.currentOdometer, allowLowerValue: false)
        switch result {
        case .valid: if let v = VehicleInsightService.shared.parsedOdometer(odometerText) { save(v) }
        case .empty: errorMessage = "Yeni kilometre değerini girmelisin."
        case .invalid: errorMessage = "Geçerli bir kilometre değeri girmelisin."
        case .negative: errorMessage = "Km sıfırdan küçük olamaz."
        case .lowerNeedsConfirmation: pendingLowerValue = VehicleInsightService.shared.parsedOdometer(odometerText); showLowerConfirmation = true
        }
    }
    private func save(_ value: Int) {
        Task {
            do {
                try await VehicleContextRefreshService.updateCurrentOdometer(vehicle: vehicle, newOdometer: value, context: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch { errorMessage = "Kaydedilemedi: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Upcoming Task Card
struct UpcomingTaskCard: View {
    let reminder: Reminder
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: reminder.type.defaultIcon).font(.title3).foregroundColor(statusColor).frame(width: 40, height: 40).background(Circle().fill(statusColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle).font(AppTypography.captionMedium).foregroundColor(statusColor)
                Text(reminder.title).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary)
                if let dueDate = reminder.dueDate { Text(dueDate.formatted(date: .abbreviated, time: .omitted)).font(AppTypography.caption).foregroundColor(AppColors.textSecondary) }
            }
            Spacer()
            if reminder.isOverdue { Text("\(reminder.daysOverdue) gün").font(AppTypography.captionMedium).foregroundColor(AppColors.critical) }
            else if reminder.isToday { Text("Bugün").font(AppTypography.captionMedium).foregroundColor(AppColors.warning) }
            else { Text("\(reminder.daysRemaining) gün").font(AppTypography.captionMedium).foregroundColor(AppColors.textSecondary) }
        }
        .padding(AppSpacing.md).background(RoundedRectangle(cornerRadius: AppRadius.card).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(statusColor.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine).accessibilityLabel("\(statusTitle): \(reminder.title)")
    }
    private var statusColor: Color { reminder.isOverdue ? AppColors.critical : (reminder.isToday ? AppColors.warning : AppColors.accentPrimary) }
    private var statusTitle: String { reminder.isOverdue ? "Gecikmiş İş" : (reminder.isToday ? "Bugün" : "Yaklaşan İş") }
}

// MARK: - Vehicle Detail Guide Card
struct VehicleDetailGuideCard: View {
    let insight: VehicleInsight; let primaryAction: () -> Void; let dismissAction: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(color).frame(width: 28, height: 28).background(Circle().fill(color.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                Text(insight.body).font(AppTypography.caption).foregroundColor(AppColors.textSecondary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: AppSpacing.xs) {
                    Button(action: primaryAction) { HStack(spacing: 4) { Text(insight.action.title).font(AppTypography.captionMedium); Image(systemName: "arrow.right").font(.caption2.weight(.semibold)) }.foregroundColor(color) }.buttonStyle(.plain)
                    Spacer()
                    Button(action: dismissAction) { Text("Daha sonra").font(AppTypography.caption).foregroundColor(AppColors.textTertiary) }.buttonStyle(.plain).accessibilityLabel("Öneriyi gizle")
                }.frame(minHeight: 32)
            }
        }
        .padding(AppSpacing.md).background(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).fill(Color.appSurface))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppColors.border.opacity(0.85), lineWidth: 0.5))
        .accessibilityElement(children: .combine).accessibilityLabel("\(insight.title). \(insight.body)")
    }
    private var color: Color { switch insight.priority { case .important: AppColors.critical; case .warning: AppColors.warning; case .info: AppColors.accentPrimary } }
    private var icon: String { switch insight.type { case .overdueReminder: "exclamationmark.triangle.fill"; case .upcomingReminder: "bell.badge"; case .calendarPeriod: "calendar.badge.clock"; case .odometerUpdate: "gauge.with.needle"; case .seasonalGuidance: "sun.max"; case .missingDocument: "doc.text"; case .monthlyExpensePrompt: "turkishlirasign.circle"; case .fuelTypeGuidance: "fuelpump"; case .transmissionGuidance: "gearshape.2"; case .odometerMilestone: "flag.checkered"; case .maintenance: "wrench.and.screwdriver"; case .quietGoodState: "checkmark.seal"; case .saleFileReadiness: "doc.richtext" } }
}

// MARK: - Contextual Insight Compact Card
struct ContextualInsightCompactCard: View {
    let insight: VehicleInsight; var prominence: Prominence = .secondary; let action: () -> Void
    enum Prominence { case primary; case secondary }
    var body: some View {
        VStack(alignment: .leading, spacing: prominence == .primary ? AppSpacing.md : AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon).font(prominence == .primary ? .title3 : .body).foregroundColor(color).frame(width: prominence == .primary ? 42 : 32, height: prominence == .primary ? 42 : 32).background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(color.opacity(prominence == .primary ? 0.15 : 0.1))).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(insight.title).font(prominence == .primary ? AppTypography.cardTitle : AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary).fixedSize(horizontal: false, vertical: true)
                    Text(insight.body).font(prominence == .primary ? AppTypography.secondarySmall : AppTypography.caption).foregroundColor(AppColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button { action() } label: { HStack(spacing: AppSpacing.xs) { Text(insight.action.title).font(AppTypography.captionMedium); Image(systemName: "arrow.right").font(.caption2.weight(.semibold)) }.foregroundColor(prominence == .primary ? AppColors.textOnAccent : AppColors.accentPrimary).padding(.horizontal, prominence == .primary ? AppSpacing.sm : 0).frame(minHeight: AppSpacing.minimumTapTarget, alignment: .leading).background(Capsule().fill(prominence == .primary ? color : Color.clear)) }.buttonStyle(.plain)
        }
        .padding(prominence == .primary ? AppSpacing.md : AppSpacing.sm).background(RoundedRectangle(cornerRadius: prominence == .primary ? AppRadius.heroCard : AppRadius.card).fill(backgroundFill))
        .overlay(RoundedRectangle(cornerRadius: prominence == .primary ? AppRadius.heroCard : AppRadius.card).stroke(color.opacity(prominence == .primary ? 0.2 : 0.12), lineWidth: 1))
        .subtleShadow().accessibilityElement(children: .combine).accessibilityLabel("\(insight.title). \(insight.body)")
    }
    private var backgroundFill: LinearGradient { LinearGradient(colors: prominence == .primary ? [Color.appSurface, color.opacity(0.095)] : [Color.appSurface, AppColors.backgroundSecondary.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing) }
    private var color: Color { switch insight.priority { case .important: AppColors.critical; case .warning: AppColors.warning; case .info: AppColors.accentPrimary } }
    private var icon: String { switch insight.type { case .overdueReminder: "exclamationmark.triangle.fill"; case .upcomingReminder: "bell.badge"; case .calendarPeriod: "calendar.badge.clock"; case .odometerUpdate: "gauge.with.needle"; case .seasonalGuidance: "sun.max"; case .missingDocument: "doc.text"; case .monthlyExpensePrompt: "turkishlirasign.circle"; case .fuelTypeGuidance: "fuelpump"; case .transmissionGuidance: "gearshape.2"; case .odometerMilestone: "flag.checkered"; case .maintenance: "wrench.and.screwdriver"; case .quietGoodState: "checkmark.seal"; case .saleFileReadiness: "doc.richtext" } }
}

// MARK: - Recent Record Item
struct RecentRecordItem: Identifiable {
    let id: UUID; let type: RecordType; let title: String; let subtitle: String; let date: Date; let icon: String
    enum RecordType { case expense; case service }
}

// MARK: - Vehicle Detail Milestone Card
// Araç yaşam çizgisindeki kritik milestone'lar için ayrıcalıklı kart.
// Karar 3.3 (Stratejik Kararlar Manifestosu). Mevcut timeline davranışı korunur;
// milestone event'ler bu kartla render edilir, regular event'ler mevcut sade liste hali kalır.
struct VehicleDetailMilestoneCard: View {
    enum MilestoneKind: String {
        case purchase       // araç satın alma
        case majorService   // ilk büyük bakım (parts_cost > 5000 veya major serviceType)
        case inspection     // ekspertiz raporu
        case saleFile       // satış dosyası
        case ownershipYear  // 5+ yıl sahiplik

        /// Her milestone için uygun icon.
        var defaultIcon: String {
            switch self {
            case .purchase: return "cart.fill"
            case .majorService: return "wrench.and.screwdriver.fill"
            case .inspection: return "checkmark.seal.fill"
            case .saleFile: return "doc.richtext.fill"
            case .ownershipYear: return "flag.checkered"
            }
        }

        /// Her milestone türü için accent rengi — design token üzerinden.
        var defaultAccent: Color {
            switch self {
            case .purchase: return AppColors.accentPrimary
            case .majorService: return AppColors.vehicle
            case .inspection: return AppColors.success
            case .saleFile: return AppColors.accentPrimary
            case .ownershipYear: return AppColors.warning
            }
        }

        /// Helper — milestone türünü Türkçe etiket olarak döner.
        var displayLabel: String {
            switch self {
            case .purchase: return "Satın Alma"
            case .majorService: return "Büyük Bakım"
            case .inspection: return "Ekspertiz"
            case .saleFile: return "Satış Dosyası"
            case .ownershipYear: return "Sahiplik Yıl Dönümü"
            }
        }
    }

    let kind: MilestoneKind
    let date: Date
    let title: String
    let subtitle: String?
    let icon: String
    let accent: Color

    private var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // İkon container — çevresinde accent ring
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 2)
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(kind.displayLabel)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(accent)
                    Spacer(minLength: 0)
                    Text(formattedDate)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .monospacedDigit()
                }

                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(accent.opacity(0.3), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.displayLabel): \(title), \(formattedDate)")
    }
}

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
    .preferredColorScheme(.dark)
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
