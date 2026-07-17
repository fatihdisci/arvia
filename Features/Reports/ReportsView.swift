import SwiftUI
import SwiftData
import Charts

// MARK: - Reports View
// Araç masraf raporları: sahiplik maliyeti özeti.
// Sakin, okunaklı, güvenilir — araç sahiplik dashboard'u.

struct ReportsView: View {
    @EnvironmentObject private var paywallService: PaywallService
    @EnvironmentObject private var navigationRouter: AppNavigationRouter
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var selectedVehicleId: UUID?
    @State private var selectedYear: Int
    @State private var showSaleFile = false
    @State private var saleFileVehicle: Vehicle?
    @State private var showVehiclePicker = false
    @State private var showAddExpense = false
    @State private var showReportsPaywall = false

    private let currentYear = Calendar.current.component(.year, from: Date())

    init() {
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    private var filteredExpenses: [Expense] {
        let byVehicle = selectedVehicleId == nil
            ? allExpenses
            : allExpenses.filter { $0.vehicleId == selectedVehicleId }
        return byVehicle.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
    }

    private var yearlyTotal: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var monthlyData: [(month: String, total: Double)] {
        let months = Calendar.current.shortMonthSymbols
        var result: [(String, Double)] = []
        for (i, name) in months.enumerated() {
            let total = filteredExpenses
                .filter { Calendar.current.component(.month, from: $0.date) == i + 1 }
                .reduce(0) { $0 + $1.amount }
            result.append((name, total))
        }
        return result
    }

    private var categoryData: [(category: ExpenseCategory, total: Double, percentage: Double)] {
        var dict: [ExpenseCategory: Double] = [:]
        for e in filteredExpenses { dict[e.category, default: 0] += e.amount }
        let total = yearlyTotal
        return dict
            .map { ($0.key, $0.value, total > 0 ? ($0.value / total) * 100 : 0) }
            .sorted { $0.total > $1.total }
    }

    private var costPerKm: Double? {
        ReportMetrics.costPerKm(
            totalCost: yearlyTotal,
            odometerReadings: filteredExpenses.compactMap(\.odometer)
        )
    }

    private var topExpenses: [Expense] {
        Array(filteredExpenses.sorted { $0.amount > $1.amount }.prefix(5))
    }

    private var selectedVehicle: Vehicle? {
        vehicles.first { $0.id == selectedVehicleId }
    }

    // MARK: - Computed Insights
    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1
    }

    private var currentMonthTotal: Double {
        guard currentMonthIndex < monthlyData.count else { return 0 }
        return monthlyData[currentMonthIndex].total
    }

    private var lastMonthTotal: Double {
        let prevIndex = currentMonthIndex - 1
        guard prevIndex >= 0, prevIndex < monthlyData.count else { return 0 }
        return monthlyData[prevIndex].total
    }

    private var biggestExpense: (category: String, amount: Double)? {
        guard let top = topExpenses.first else { return nil }
        return (top.category.displayName, top.amount)
    }

    private var mostExpensiveMonth: (month: String, amount: Double)? {
        monthlyData.max(by: { $0.total < $1.total })
            .flatMap { $0.total > 0 ? ($0.month, $0.total) : nil }
    }

    private var lastYearTotal: Double {
        allExpenses
            .filter {
                Calendar.current.component(.year, from: $0.date) == selectedYear - 1
                    && (selectedVehicleId == nil || $0.vehicleId == selectedVehicleId)
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var yearTrendLabel: String? {
        guard lastYearTotal > 0, yearlyTotal > 0 else { return nil }
        let change = ((yearlyTotal - lastYearTotal) / lastYearTotal) * 100
        if change > 5 { return "Geçen yıla göre %\(Int(abs(change))) daha fazla" }
        if change < -5 { return "Geçen yıla göre %\(Int(abs(change))) daha az" }
        return "Geçen yıla benzer seviyede"
    }

    // 1.1.0'da "Raporlar" kendi ana sekmesi — önceden "Kayıtlar" altında
    // segment'ti (bkz. git log). Kendi NavigationStack'ini burada açar.
    var body: some View {
        NavigationStack {
            Group {
                if allExpenses.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar.fill",
                        title: "Henüz rapor oluşmadı",
                        description: "Masraf ve bakım kayıtları ekledikçe aracının maliyet özeti burada oluşur.",
                        actionTitle: "Masraf Ekle",
                        action: { showAddExpense = true }
                    )
                } else {
                    reportContent
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Raporlar")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddExpense = true } label: {
                        Image(systemName: "plus")
                            .font(.body)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .accessibilityLabel("Masraf Ekle")
                }
            }
            .sheet(isPresented: $showAddExpense) { ExpenseFormView() }
            .sheet(isPresented: $showReportsPaywall) { PaywallView(feature: .advancedReports) }
            .sheet(item: $saleFileVehicle) { vehicle in
                if PaywallService.shared.canCreateSaleFile() {
                    SaleFileView(vehicle: vehicle)
                } else {
                    PaywallView(feature: .saleFileExport)
                }
            }
            .confirmationDialog("Satış dosyası hangi araç için?", isPresented: $showVehiclePicker) {
                ForEach(vehicles) { v in
                    Button(v.plate.isEmpty ? v.fullName : "\(v.plate) · \(v.fullName)") {
                        openSaleFile(for: v)
                    }
                }
                Button("Vazgeç", role: .cancel) {}
            }
        }
        .onAppear { clearPendingReportsRouteIfNeeded() }
        .onChange(of: navigationRouter.pendingNotificationRoute) { _, _ in
            clearPendingReportsRouteIfNeeded()
        }
    }

    private func clearPendingReportsRouteIfNeeded() {
        guard navigationRouter.pendingNotificationRoute == .reports else { return }
        navigationRouter.clearRouteIfHandled(.reports)
    }

    // MARK: - Content
    private var reportContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Supporting copy
                Text("Aracının yıllık masrafını, kategori dağılımını ve maliyet ritmini gör.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.screenMarginH)

                filters

                // Hero metric
                PremiumMetricHero(
                    label: selectedYear == currentYear ? "Bu yılki toplam masraf" : "\(String(selectedYear)) yılı toplam masraf",
                    value: currencyFormat(yearlyTotal),
                    vehicleName: selectedVehicle.map { $0.plate.isEmpty ? $0.fullName : "\($0.plate) · \($0.fullName)" },
                    insightLine: paywallService.canAccessAdvancedReports() ? yearTrendLabel : nil
                )

                basicSummaryGrid

                if paywallService.canAccessAdvancedReports() {
                    insightCardsGrid
                    monthlyChart
                    categorySection
                    topExpensesSection
                    saleFileCTA
                } else {
                    advancedReportsLock
                }

                Spacer().frame(height: AppSpacing.floatingTabBarContentInset)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    // MARK: - Free Summary
    private var basicSummaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            if selectedYear == currentYear {
                OwnershipInsightCard(
                    icon: "calendar",
                    title: "Bu Ay",
                    value: currencyFormat(currentMonthTotal),
                    subtitle: nil,
                    color: AppColors.accentPrimary
                )
            }

            OwnershipInsightCard(
                icon: "list.bullet.rectangle",
                title: "Masraf Kaydı",
                value: String(filteredExpenses.count),
                subtitle: selectedYear == currentYear ? "bu yıl" : "\(selectedYear) yılında",
                color: AppColors.vehicle
            )
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private var advancedReportsLock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3)
                    .foregroundColor(AppColors.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gelişmiş Analizler")
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Masraf kayıtlarını karşılaştırmalı içgörülere dönüştür.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.warning)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                lockedBenefit("Aylık grafik ve kategori dağılımı")
                lockedBenefit("Km başı maliyet ve yıllık karşılaştırma")
                lockedBenefit("En yüksek giderler ve satış dosyası")
            }

            Button("Pro ile Analiz Et") {
                showReportsPaywall = true
            }
            .buttonStyle(.primary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.warning.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func lockedBenefit(_ text: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle")
                .font(.caption)
                .foregroundColor(AppColors.accentPrimary)
            Text(text)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Filters
    private var selectedVehicleLabel: String {
        if let v = selectedVehicle {
            return v.plate.isEmpty ? v.fullName : v.plate
        }
        return "Tüm Araçlar"
    }

    private var filters: some View {
        HStack(spacing: AppSpacing.xs) {
            if vehicles.count > 1 {
                Menu {
                    Button { selectedVehicleId = nil } label: {
                        HStack {
                            Text("Tüm Araçlar")
                            if selectedVehicleId == nil { Image(systemName: "checkmark") }
                        }
                    }
                    ForEach(vehicles) { v in
                        Button { selectedVehicleId = v.id } label: {
                            HStack {
                                Text(v.plate.isEmpty ? v.fullName : v.plate)
                                if selectedVehicleId == v.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.caption2)
                        Text(selectedVehicleLabel)
                            .font(AppTypography.captionMedium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(selectedVehicleId == nil ? AppColors.textSecondary : AppColors.accentPrimary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        Capsule()
                            .fill(selectedVehicleId == nil ? AppColors.backgroundSecondary : AppColors.accentPrimary.opacity(0.1))
                    )
                }
            }

            Menu {
                ForEach(availableYears(), id: \.self) { year in
                    Button { selectedYear = year } label: {
                        HStack {
                            Text(String(year))
                            if selectedYear == year { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(selectedYear))
                        .font(AppTypography.captionMedium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.accentPrimary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.accentPrimary.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func availableYears() -> [Int] {
        let years = allExpenses.map { Calendar.current.component(.year, from: $0.date) }
        guard let minYear = years.min(), let maxYear = years.max() else { return [currentYear] }
        return Array(minYear...maxYear).reversed()
    }

    // MARK: - Insight Cards Grid
    private var insightCardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
            if let cpk = costPerKm {
                OwnershipInsightCard(
                    icon: "gauge.with.needle",
                    title: "Km Başı Maliyet",
                    value: currencyFormat(cpk),
                    subtitle: nil,
                    color: AppColors.vehicle
                )
            }

            if let biggest = biggestExpense {
                OwnershipInsightCard(
                    icon: "arrow.up.right",
                    title: "En Büyük Gider",
                    value: currencyFormat(biggest.amount),
                    subtitle: biggest.category,
                    color: AppColors.critical
                )
            }

            if let expensive = mostExpensiveMonth {
                OwnershipInsightCard(
                    icon: "calendar.badge.exclamationmark",
                    title: "En Masraflı Ay",
                    value: currencyFormat(expensive.amount),
                    subtitle: expensive.month,
                    color: AppColors.warning
                )
            }

            OwnershipInsightCard(
                icon: "arrow.left.arrow.right",
                title: "Bu Ay / Geçen Ay",
                value: currencyFormat(currentMonthTotal),
                subtitle: lastMonthTotal > 0 ? "\(currencyFormat(lastMonthTotal)) geçen ay" : nil,
                color: AppColors.success
            )
        }
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Monthly Chart
    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aylık Dağılım")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("Aylara göre harcama akışı")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Chart {
                ForEach(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("Ay", item.month),
                        y: .value("Tutar", item.total)
                    )
                    .foregroundStyle(
                        item.total > 0
                            ? AppColors.accentPrimary.opacity(0.72)
                            : AppColors.border
                    )
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(height: 180)
            .padding(.vertical, AppSpacing.xs)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Category Breakdown
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kategori Dağılımı")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("Kategori bazında dağılım")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(categoryData.prefix(8), id: \.category) { item in
                    categoryRow(item)
                }

                if categoryData.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "chart.pie")
                            .font(.body)
                            .foregroundColor(AppColors.textTertiary)
                        Text("Bu yıl için kategori verisi yok.")
                            .font(AppTypography.secondary)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.md)
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
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func categoryRow(_ item: (category: ExpenseCategory, total: Double, percentage: Double)) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: item.category.defaultIcon)
                    .font(.caption)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 22)

                Text(item.category.displayName)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(currencyFormat(item.total))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.backgroundSecondary)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accentPrimary.opacity(0.55))
                        .frame(width: max(geo.size.width * CGFloat(item.percentage / 100.0), 4), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - Top Expenses
    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("En Yüksek Masraflar")
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("Bu yılın en büyük 5 gideri")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            if topExpenses.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                    Text("Bu yıl için veri yok.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, AppSpacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topExpenses.enumerated()), id: \.element.id) { index, expense in
                        topExpenseRow(index: index + 1, expense: expense)
                        if index < topExpenses.count - 1 {
                            Divider().padding(.leading, 48)
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
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func topExpenseRow(index: Int, expense: Expense) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(String(index))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 20)

            Image(systemName: expense.category.defaultIcon)
                .font(.caption)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.displayName)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)
                if let vendor = expense.vendorName, !vendor.isEmpty {
                    Text(vendor)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amountCompactDisplay)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
                Text(expense.dateDisplay)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Sale File CTA
    private var saleFileCTA: some View {
        Button {
            if vehicles.count == 1, let only = vehicles.first {
                openSaleFile(for: only)
            } else {
                showVehiclePicker = true
            }
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
                    Text("Kayıtlarından satış dosyası oluştur")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Bakım geçmişi, masraf özeti ve belgelerinle güven dosyası hazırla.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }()

    private func currencyFormat(_ value: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "₺0,00"
    }

    private func openSaleFile(for vehicle: Vehicle) {
        saleFileVehicle = vehicle
    }
}

enum ReportMetrics {
    /// Km başı maliyet, yıl içindeki gerçek okuma farkına göre hesaplanır.
    /// Tek bir odometre değerini toplam mesafe saymak yanıltıcı olacağı için
    /// en az iki farklı okuma gerekir.
    static func costPerKm(totalCost: Double, odometerReadings: [Int]) -> Double? {
        let readings = Array(Set(odometerReadings.filter { $0 >= 0 })).sorted()
        guard totalCost > 0,
              let first = readings.first,
              let last = readings.last,
              readings.count >= 2,
              last > first else { return nil }
        return totalCost / Double(last - first)
    }
}

// MARK: - Preview
#Preview("Raporlar — Dolu") {
    ReportsView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
}

#Preview("Raporlar — Dark Mode") {
    ReportsView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
}

#Preview("Raporlar — Dynamic Type") {
    ReportsView()
        .modelContainer(MockDataProvider.previewContainer)
        .environmentObject(PaywallService.shared)
        .environmentObject(AppNavigationRouter.shared)
        .environment(\.dynamicTypeSize, .accessibility1)
}
