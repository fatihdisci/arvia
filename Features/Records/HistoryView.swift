import SwiftUI
import SwiftData
import QuickLook

// MARK: - Geçmiş (History) Tab
// Bakım, masraf, belge ve ekspertiz geçmiş kayıtları.
// Filtre: Tümü, Masraflar, Bakımlar, Belgeler, Ekspertiz

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \ServiceRecord.date, order: .reverse) private var allServiceRecords: [ServiceRecord]
    @Query(sort: \VehicleDocument.createdAt, order: .reverse) private var allDocuments: [VehicleDocument]
    @Query(sort: \InspectionReport.reportDate, order: .reverse) private var allInspections: [InspectionReport]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var selectedFilter: HistoryFilter = .all
    @State private var showAddExpense = false
    @State private var showAddService = false
    @State private var showAddDocument = false
    @State private var showAddInspection = false
    @State private var previewURL: URL?

    enum HistoryFilter: String, CaseIterable {
        case all = "Tümü"
        case expenses = "Masraflar"
        case services = "Bakımlar"
        case documents = "Belgeler"
        case inspections = "Ekspertiz"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtre çipleri
                filterRail

                // İçerik
                Group {
                    if isEmpty {
                        emptyState
                    } else {
                        historyList
                    }
                }
                .background(Color.appBackground)
            }
            .navigationTitle("Geçmiş")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showAddExpense = true } label: {
                            Label("Masraf Ekle", systemImage: "turkishlirasign.circle")
                        }
                        Button { showAddService = true } label: {
                            Label("Bakım Ekle", systemImage: "wrench.and.screwdriver")
                        }
                        Button { showAddDocument = true } label: {
                            Label("Belge Ekle", systemImage: "doc.text")
                        }
                        Button { showAddInspection = true } label: {
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
            .quickLookPreview($previewURL)
        }
    }

    // MARK: - Filter Rail
    private var filterRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(selectedFilter == filter ? .white : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? AppColors.accentPrimary : AppColors.backgroundSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
            .padding(.vertical, AppSpacing.xs)
        }
    }

    // MARK: - Empty State
    private var isEmpty: Bool {
        switch selectedFilter {
        case .all: return allExpenses.isEmpty && allServiceRecords.isEmpty && allDocuments.isEmpty && allInspections.isEmpty
        case .expenses: return allExpenses.isEmpty
        case .services: return allServiceRecords.isEmpty
        case .documents: return allDocuments.isEmpty
        case .inspections: return allInspections.isEmpty
        }
    }

    private var emptyState: some View {
        Group {
            switch selectedFilter {
            case .all:
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Henüz geçmiş kaydı yok",
                    description: "Yaptığın bakımları, masrafları ve belgeleri aracının dijital geçmişi olarak saklayabilirsin.",
                    actionTitle: "İlk Kaydı Ekle",
                    action: { showAddExpense = true }
                )
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
                    action: { showAddDocument = true }
                )
            case .inspections:
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "Henüz ekspertiz kaydı yok",
                    description: "Ekspertiz raporlarını manuel ekleyerek satış dosyana dahil edebilirsin.",
                    actionTitle: "Ekspertiz Ekle",
                    action: { showAddInspection = true }
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
    }

    // MARK: - Timeline (Tümü)
    private var historyTimelineSection: some View {
        let items = buildTimeline()
        return ForEach(items) { item in
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: item.icon)
                    .font(.subheadline)
                    .foregroundColor(item.color)
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
                Text(item.dateDisplay)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, AppSpacing.xxs)
        }
    }

    // MARK: - Expense Section
    private var expenseSection: some View {
        ForEach(allExpenses) { expense in
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: expense.category.defaultIcon)
                    .foregroundColor(AppColors.accentPrimary).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(expense.category.displayName)
                        .font(AppTypography.secondary).foregroundColor(AppColors.textPrimary)
                    if let vendor = expense.vendorName, !vendor.isEmpty {
                        Text(vendor).font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(expense.amountCompactDisplay)
                        .font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary)
                    Text(expense.dateDisplay)
                        .font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
        }
    }

    // MARK: - Service Section
    private var serviceSection: some View {
        ForEach(allServiceRecords) { record in
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(AppColors.warning).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.serviceType.displayName)
                        .font(AppTypography.secondary).foregroundColor(AppColors.textPrimary)
                    if let vendor = record.vendorName, !vendor.isEmpty {
                        Text(vendor).font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let totalDisplay = record.totalCostDisplay {
                        Text(totalDisplay).font(AppTypography.bodyMedium).foregroundColor(AppColors.textPrimary)
                    }
                    Text(record.date.formatted(date: .numeric, time: .omitted))
                        .font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
        }
    }

    // MARK: - Document Section
    private var documentSection: some View {
        ForEach(allDocuments) { doc in
            Button {
                if let url = DocumentStorageService.shared.materializeFileIfNeeded(localFileName: doc.localFileName, data: doc.fileData) {
                    previewURL = url
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: doc.type.defaultIcon)
                        .foregroundColor(AppColors.document).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title.isEmpty ? doc.type.displayName : doc.title)
                            .font(AppTypography.secondary).foregroundColor(AppColors.textPrimary)
                        if let size = doc.fileSizeDisplay {
                            Text(size).font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                        }
                    }
                    Spacer()
                    statusBadge(doc)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, AppSpacing.xxs)
        }
    }

    private func statusBadge(_ doc: VehicleDocument) -> some View {
        if doc.isExpired {
            return AnyView(
                Text("Süresi Geçti")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.critical)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.critical.opacity(0.12)))
            )
        } else if doc.isExpiringSoon {
            return AnyView(
                Text("\(doc.daysUntilExpiry ?? 0) gün")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.warning.opacity(0.12)))
            )
        }
        return AnyView(EmptyView())
    }

    // MARK: - Inspection Section
    private var inspectionSection: some View {
        ForEach(allInspections) { report in
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.accentPrimary).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.providerName).font(AppTypography.secondary).foregroundColor(AppColors.textPrimary)
                    if let branch = report.branchName, !branch.isEmpty {
                        Text(branch).font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer()
                Text(report.dateDisplay)
                    .font(AppTypography.caption).foregroundColor(AppColors.textTertiary)
            }
            .padding(.vertical, AppSpacing.xxs)
        }
    }

    // MARK: - Timeline Builder
    private struct HistoryTimelineItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let dateDisplay: String
        let color: Color
    }

    private func buildTimeline() -> [HistoryTimelineItem] {
        var items: [HistoryTimelineItem] = []
        for e in allExpenses {
            items.append(HistoryTimelineItem(icon: e.category.defaultIcon, title: e.category.displayName, subtitle: e.vendorName ?? "", dateDisplay: e.dateDisplay, color: AppColors.accentPrimary))
        }
        for s in allServiceRecords {
            items.append(HistoryTimelineItem(icon: "wrench.and.screwdriver", title: s.serviceType.displayName, subtitle: s.vendorName ?? "", dateDisplay: s.date.formatted(date: .numeric, time: .omitted), color: AppColors.warning))
        }
        for d in allDocuments {
            items.append(HistoryTimelineItem(icon: d.type.defaultIcon, title: d.title.isEmpty ? d.type.displayName : d.title, subtitle: d.fileSizeDisplay ?? "", dateDisplay: d.createdAt.formatted(date: .numeric, time: .omitted), color: AppColors.document))
        }
        for i in allInspections {
            items.append(HistoryTimelineItem(icon: "magnifyingglass", title: i.providerName, subtitle: i.branchName ?? "", dateDisplay: i.dateDisplay, color: AppColors.accentPrimary))
        }
        return items.sorted { $0.dateDisplay > $1.dateDisplay }.prefix(50).map { $0 }
    }

    // MARK: - Vehicle helper
    private func vehicleFor(id: UUID) -> Vehicle? {
        vehicles.first { $0.id == id }
    }
}

#Preview("Geçmiş") {
    HistoryView()
        .modelContainer(MockDataProvider.previewContainer)
}
