import SwiftUI
import SwiftData
import QuickLook

// MARK: - Geçmiş (History) Tab
// Bakım, masraf, belge ve ekspertiz geçmiş kayıtları.
// Araç arşivi — düzenli, filtrelenebilir, premium.

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \ServiceRecord.date, order: .reverse) private var allServiceRecords: [ServiceRecord]
    @Query(sort: \VehicleDocument.createdAt, order: .reverse) private var allDocuments: [VehicleDocument]
    @Query(sort: \InspectionReport.reportDate, order: .reverse) private var allInspections: [InspectionReport]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<Reminder> { $0.statusRaw == "Tamamlandı" && $0.addedToHistoryAt != nil },
           sort: \Reminder.addedToHistoryAt, order: .reverse)
    private var completedReminders: [Reminder]

    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedDateRange: DateRange = .all
    @State private var showAddExpense = false
    @State private var showAddService = false
    @State private var showAddDocument = false
    @State private var showAddInspection = false
    @State private var previewURL: URL?
    @State private var editingExpense: Expense?
    @State private var editingService: ServiceRecord?
    @State private var editingInspection: InspectionReport?
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: Any? = nil

    enum HistoryFilter: String, CaseIterable {
        case all = "Tümü"
        case expenses = "Masraflar"
        case services = "Bakımlar"
        case documents = "Belgeler"
        case inspections = "Ekspertiz"
    }

    enum DateRange: String, CaseIterable {
        case all = "Tüm Zaman"
        case oneMonth = "Son 1 Ay"
        case sixMonths = "Son 6 Ay"
        case oneYear = "Son 1 Yıl"

        var calendarValue: Int? {
            switch self {
            case .all: return nil
            case .oneMonth: return -1
            case .sixMonths: return -6
            case .oneYear: return -12
            }
        }
    }

    // Not: "Kayıtlar" sekmesi altında (RecordsView) segment olarak gösterilir.
    // Kendi NavigationStack'i yok — üst konteynerin nav bar'ını kullanır;
    // toolbar/sheet modifier'ları konteyner nav bar'ına bağlanır.
    var body: some View {
        VStack(spacing: 0) {
            // Compact supporting copy
            Text("Bakım, masraf, belge ve tamamlanan işleri tek arşivde gör.")
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.screenMarginH)
                .padding(.bottom, AppSpacing.xs)

            // Filtre çipleri
            filterRail
            dateFilterRail

            // İçerik
            Group {
                if isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }

            // Boş state'te son öğenin tab bar altına girmemesi için
            if isEmpty {
                Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showAddExpense = true } label: {
                        Label("Masraf Ekle", systemImage: "turkishlirasign.circle")
                    }
                    Button { showAddService = true } label: {
                        Label("Bakım Ekle", systemImage: "wrench.and.screwdriver")
                    }
                    Button { handleAddDocument() } label: {
                        Label("Belge Ekle", systemImage: "doc.text")
                    }
                    Button { handleAddInspection() } label: {
                        Label("Ekspertiz Ekle", systemImage: "magnifyingglass")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .foregroundColor(AppColors.accentPrimary)
                }
                .accessibilityLabel("Kayıt Ekle")
            }
        }
        .sheet(isPresented: $showAddExpense) { ExpenseFormView() }
        .sheet(isPresented: $showAddService) { ServiceRecordFormView() }
        .sheet(isPresented: $showAddDocument) { DocumentFormView() }
        .sheet(isPresented: $showAddInspection) { InspectionReportFormView() }
        .sheet(item: $editingExpense) { expense in ExpenseFormView(existingExpense: expense) }
        .sheet(item: $editingService) { service in ServiceRecordFormView(existingRecord: service) }
        .sheet(item: $editingInspection) { report in InspectionReportFormView(existingReport: report) }
        .confirmationDialog("Kayıt Silinsin mi?", isPresented: $showDeleteConfirmation, actions: {
            Button("Sil", role: .destructive) { performDelete() }
            Button("Vazgeç", role: .cancel) {}
        }, message: { Text("Bu işlem geri alınamaz.") })
        .quickLookPreview($previewURL)
    }

    // MARK: - Filter Rails
    private var filterRail: some View {
        Picker("Filtre", selection: $selectedFilter) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.xxs)
    }

    private var dateFilterRail: some View {
        HStack {
            Menu {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Button(range.rawValue) {
                        selectedDateRange = range
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "calendar")
                    Text(selectedDateRange.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.accentPrimary.opacity(0.08))
                )
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - Date Range Helper
    private var dateRangeCutoff: Date? {
        guard let months = selectedDateRange.calendarValue else { return nil }
        return Calendar.current.date(byAdding: .month, value: months, to: Date())
    }

    private func isWithinDateRange(_ date: Date) -> Bool {
        guard let cutoff = dateRangeCutoff else { return true }
        return date >= cutoff
    }

    // MARK: - Empty State
    private var isEmpty: Bool {
        switch selectedFilter {
        case .all:
            let hasItems = allExpenses.contains { isWithinDateRange($0.date) }
                || allServiceRecords.contains { isWithinDateRange($0.date) }
                || allDocuments.contains { isWithinDateRange($0.createdAt) }
                || allInspections.contains { isWithinDateRange($0.reportDate) }
                || completedReminders.contains { isWithinDateRange($0.addedToHistoryAt ?? .distantPast) }
            return !hasItems
        case .expenses: return allExpenses.filter { isWithinDateRange($0.date) }.isEmpty
        case .services: return allServiceRecords.filter { isWithinDateRange($0.date) }.isEmpty
        case .documents: return allDocuments.filter { isWithinDateRange($0.createdAt) }.isEmpty
        case .inspections: return allInspections.filter { isWithinDateRange($0.reportDate) }.isEmpty
        }
    }

    private var emptyState: some View {
        Group {
            switch selectedFilter {
            case .all:
                VStack(spacing: AppSpacing.lg) {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "Aracının geçmişi burada oluşacak",
                        description: "Masraf, bakım, belge veya tamamlanan işleri ekledikçe aracının geçmişi tek arşivde birikir."
                    )

                    HStack(spacing: AppSpacing.sm) {
                        quickAddButton(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {
                            showAddExpense = true
                        }
                        quickAddButton(icon: "wrench.and.screwdriver", label: "Bakım", color: AppColors.warning) {
                            showAddService = true
                        }
                        quickAddButton(icon: "doc.text", label: "Belge", color: AppColors.document) {
                            handleAddDocument()
                        }
                    }

                    Divider().padding(.vertical, AppSpacing.xs)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Aracının geçmişini nasıl oluşturursun?")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        tourStep(number: 1, text: "İlk kaydı ekle (örn. son yakıt alma)")
                        tourStep(number: 2, text: "Sıradaki hatırlatıcıları Yapılacaklar'dan takip et")
                        tourStep(number: 3, text: "Geçmiş otomatik dolar, Raporlar özetler")
                    }
                }
            case .expenses:
                EmptyStateView(
                    icon: "turkishlirasign.circle",
                    title: "Henüz masraf kaydı yok",
                    description: "Yakıt, bakım, sigorta ve diğer harcamalarını ekleyerek yıllık maliyetini görebilirsin.",
                    actionTitle: "Masraf Ekle",
                    action: { showAddExpense = true }
                )
            case .services:
                EmptyStateView(
                    icon: "wrench.and.screwdriver",
                    title: "Henüz bakım kaydı yok",
                    description: "Yağ değişimi, periyodik bakım ve değişen parçaları aracının geçmişine ekleyebilirsin.",
                    actionTitle: "Bakım Ekle",
                    action: { showAddService = true }
                )
            case .documents:
                EmptyStateView(
                    icon: "doc.text",
                    title: "Henüz belge yok",
                    description: "Poliçe, muayene, ekspertiz ve faturaları aracının dosyasında saklayabilirsin.",
                    actionTitle: "Belge Ekle",
                    action: { handleAddDocument() }
                )
            case .inspections:
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Henüz ekspertiz kaydı yok",
                    description: "Ekspertiz raporlarını manuel ekleyerek satış dosyana dahil edebilirsin.",
                    actionTitle: "Ekspertiz Ekle",
                    action: { handleAddInspection() }
                )
            }
        }
    }

    // MARK: - History List
    private var historyList: some View {
        List {
            switch selectedFilter {
            case .all:
                historyTimelineSection
            case .expenses:
                expenseSection
            case .services:
                serviceSection
            case .documents:
                documentSection
            case .inspections:
                inspectionSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, AppSpacing.floatingTabBarContentInset)
    }

    // MARK: - Timeline (Tümü) — flat, date-sorted, no time grouping
    private var historyTimelineSection: some View {
        let items = buildTimeline()
        return Section {
            ForEach(items) { item in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: item.icon)
                        .font(.subheadline)
                        .foregroundColor(item.color)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                                    .lineLimit(1)
                            }
                            if !item.plateText.isEmpty {
                                if !item.subtitle.isEmpty {
                                    Text("·")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textTertiary.opacity(0.4))
                                }
                                Text(item.plateText)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                    Text(item.dateDisplay)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.vertical, AppSpacing.xxs)
            }
        }
    }

    // MARK: - Expense Section — flat
    private var expenseSection: some View {
        let filtered = allExpenses.filter { isWithinDateRange($0.date) }
        return Section {
            ForEach(filtered) { expense in
                Button {
                    editingExpense = expense
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: expense.category.defaultIcon)
                            .foregroundColor(AppColors.accentPrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(expense.category.displayName)
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if let vehicle = vehicleFor(id: expense.vehicleId) {
                                    Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                                if let vendor = expense.vendorName, !vendor.isEmpty {
                                    if vehicleFor(id: expense.vehicleId) != nil {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary.opacity(0.4))
                                    }
                                    Text(vendor)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(expense.amountCompactDisplay)
                                .font(.custom("JetBrainsMono-SemiBold", size: 16))
                                .foregroundColor(AppColors.textPrimary)
                            Text(expense.dateDisplay)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, AppSpacing.xxs)
                .swipeActions(edge: .trailing) { swipeDeleteButton(expense) }
                .swipeActions(edge: .leading) {
                    Button { editingExpense = expense } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }
                    .tint(AppColors.accentPrimary)
                }
            }
        }
    }

    // MARK: - Service Section — flat
    private var serviceSection: some View {
        let filtered = allServiceRecords.filter { isWithinDateRange($0.date) }
        return Section {
            ForEach(filtered) { record in
                Button {
                    editingService = record
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(AppColors.warning)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.serviceType.displayName)
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if let vehicle = vehicleFor(id: record.vehicleId) {
                                    Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                                if let vendor = record.vendorName, !vendor.isEmpty {
                                    if vehicleFor(id: record.vehicleId) != nil {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary.opacity(0.4))
                                    }
                                    Text(vendor)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let totalDisplay = record.totalCostDisplay {
                                Text(totalDisplay)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                    .monospacedDigit()
                            }
                            Text(record.date.formatted(date: .numeric, time: .omitted))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, AppSpacing.xxs)
                .swipeActions(edge: .trailing) { swipeDeleteButton(record) }
                .swipeActions(edge: .leading) {
                    Button { editingService = record } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }
                    .tint(AppColors.accentPrimary)
                }
            }
        }
    }

    // MARK: - Document Section — flat
    private var documentSection: some View {
        let filtered = allDocuments.filter { isWithinDateRange($0.createdAt) }
        return Section {
            ForEach(filtered) { doc in
                Button {
                    if let url = DocumentStorageService.shared.materializeFileIfNeeded(
                        localFileName: doc.localFileName, data: doc.fileData
                    ) {
                        previewURL = url
                    }
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: doc.type.defaultIcon)
                            .foregroundColor(AppColors.document)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if let vehicle = vehicleFor(id: doc.vehicleId) {
                                    Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                                if let size = doc.fileSizeDisplay {
                                    if vehicleFor(id: doc.vehicleId) != nil {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary.opacity(0.4))
                                    }
                                    Text(size)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        statusBadge(doc)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, AppSpacing.xxs)
                .swipeActions(edge: .trailing) { swipeDeleteButton(doc) }
            }
        }
    }

    private func statusBadge(_ doc: VehicleDocument) -> some View {
        if doc.isExpired {
            return AnyView(
                Text("Süresi Geçti")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.critical)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.critical.opacity(0.12)))
            )
        } else if doc.isExpiringSoon {
            return AnyView(
                Text("\(doc.daysUntilExpiry ?? 0) gün")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.warning.opacity(0.12)))
            )
        }
        return AnyView(EmptyView())
    }

    // MARK: - Inspection Section — flat
    private var inspectionSection: some View {
        let filtered = allInspections.filter { isWithinDateRange($0.reportDate) }
        return Section {
            ForEach(filtered) { report in
                Button {
                    editingInspection = report
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.accentPrimary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(report.providerName)
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                if let vehicle = vehicleFor(id: report.vehicleId) {
                                    Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                                if let branch = report.branchName, !branch.isEmpty {
                                    if vehicleFor(id: report.vehicleId) != nil {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textTertiary.opacity(0.4))
                                    }
                                    Text(branch)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Text(report.dateDisplay)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, AppSpacing.xxs)
                .swipeActions(edge: .trailing) { swipeDeleteButton(report) }
                .swipeActions(edge: .leading) {
                    Button { editingInspection = report } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }
                    .tint(AppColors.accentPrimary)
                }
            }
        }
    }

    // MARK: - Timeline Builder
    private struct HistoryTimelineItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let plateText: String
        let date: Date
        let dateDisplay: String
        let color: Color
    }

    private func buildTimeline() -> [HistoryTimelineItem] {
        var items: [HistoryTimelineItem] = []
        for e in allExpenses where isWithinDateRange(e.date) {
            let plate = vehicleFor(id: e.vehicleId).map { $0.plate.isEmpty ? $0.fullName : $0.plate } ?? ""
            items.append(HistoryTimelineItem(
                icon: e.category.defaultIcon,
                title: e.category.displayName,
                subtitle: e.vendorName ?? "",
                plateText: plate,
                date: e.date,
                dateDisplay: e.dateDisplay,
                color: AppColors.accentPrimary
            ))
        }
        for s in allServiceRecords where isWithinDateRange(s.date) {
            let plate = vehicleFor(id: s.vehicleId).map { $0.plate.isEmpty ? $0.fullName : $0.plate } ?? ""
            items.append(HistoryTimelineItem(
                icon: "wrench.and.screwdriver",
                title: s.serviceType.displayName,
                subtitle: s.vendorName ?? "",
                plateText: plate,
                date: s.date,
                dateDisplay: s.date.formatted(date: .numeric, time: .omitted),
                color: AppColors.warning
            ))
        }
        for d in allDocuments where isWithinDateRange(d.createdAt) {
            let plate = vehicleFor(id: d.vehicleId).map { $0.plate.isEmpty ? $0.fullName : $0.plate } ?? ""
            items.append(HistoryTimelineItem(
                icon: d.type.defaultIcon,
                title: d.title.isEmpty ? d.type.displayName : d.title,
                subtitle: d.fileSizeDisplay ?? "",
                plateText: plate,
                date: d.createdAt,
                dateDisplay: d.createdAt.formatted(date: .numeric, time: .omitted),
                color: AppColors.document
            ))
        }
        for i in allInspections where isWithinDateRange(i.reportDate) {
            let plate = vehicleFor(id: i.vehicleId).map { $0.plate.isEmpty ? $0.fullName : $0.plate } ?? ""
            items.append(HistoryTimelineItem(
                icon: "magnifyingglass",
                title: i.providerName,
                subtitle: i.branchName ?? "",
                plateText: plate,
                date: i.reportDate,
                dateDisplay: i.dateDisplay,
                color: AppColors.accentPrimary
            ))
        }
        for r in completedReminders where isWithinDateRange(r.addedToHistoryAt ?? .distantPast) {
            let vehicle = vehicles.first { $0.id == r.vehicleId }
            let vehicleText = vehicle.map { $0.plate.isEmpty ? $0.fullName : $0.plate } ?? ""
            let historyDate = r.addedToHistoryAt ?? r.completedAt ?? .distantPast
            items.append(HistoryTimelineItem(
                icon: "checkmark.circle",
                title: r.title,
                subtitle: "Tamamlandı",
                plateText: vehicleText,
                date: historyDate,
                dateDisplay: historyDate.formatted(date: .numeric, time: .omitted),
                color: AppColors.success
            ))
        }
        return items.sorted { $0.date > $1.date }.prefix(50).map { $0 }
    }

    // MARK: - Vehicle helper
    private func vehicleFor(id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }

    // MARK: - Delete
    private func confirmDelete(_ item: Any) {
        itemToDelete = item
        showDeleteConfirmation = true
    }

    private func performDelete() {
        guard let item = itemToDelete else { return }
        if let expense = item as? Expense {
            modelContext.delete(expense)
        } else if let service = item as? ServiceRecord {
            modelContext.delete(service)
        } else if let doc = item as? VehicleDocument {
            try? DocumentStorageService.shared.deleteFile(doc.localFileName)
            modelContext.delete(doc)
        } else if let inspection = item as? InspectionReport {
            modelContext.delete(inspection)
        }
        try? modelContext.save()
        itemToDelete = nil
    }

    // MARK: - Add helpers
    private func handleAddDocument() {
        showAddDocument = true
    }

    private func handleAddInspection() {
        showAddInspection = true
    }

    // MARK: - Quick Add + Tour Helpers (Empty State)

    private func quickAddButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.backgroundSecondary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainCardButtonStyle())
    }

    private func tourStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text("\(number)")
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(AppColors.accentPrimary.opacity(0.12)))
            Text(text)
                .font(AppTypography.secondarySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Row helper
    private func swipeDeleteButton<T>(_ item: T) -> some View {
        Button(role: .destructive) { confirmDelete(item) } label: {
            Label("Sil", systemImage: "trash")
        }
    }
}

#Preview("Geçmiş — Dolu") {
    NavigationStack {
        HistoryView()
            .navigationTitle("Kayıtlar")
    }
    .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Geçmiş — Dark") {
    NavigationStack {
        HistoryView()
            .navigationTitle("Kayıtlar")
    }
    .modelContainer(MockDataProvider.previewContainer)
}
