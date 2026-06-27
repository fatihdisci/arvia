import SwiftUI
import SwiftData
import Charts

// MARK: - Reports View
// Araç masraf raporları: sahiplik içgörüsü formatında sunulur.
// PremiumMetricHero ana görsel çapa, OwnershipInsightCard'lar destekleyici.
// Tasarım kuralı: Sakin, okunaklı, anlatısal (narrative).

struct ReportsView: View {
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var selectedVehicleId: UUID?
    @State private var selectedYear: Int

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
        let totalKm = filteredExpenses.compactMap { $0.odometer }.max() ?? 0
        guard totalKm > 0, yearlyTotal > 0 else { return nil }
        return yearlyTotal / Double(totalKm)
    }

    private var topExpenses: [Expense] {
        Array(filteredExpenses.sorted { $0.amount > $1.amount }.prefix(5))
    }

    private var selectedVehicle: Vehicle? {
        vehicles.first { $0.id == selectedVehicleId }
    }

    // MARK: - Computed Insights
    private var currentMonthIndex: Int {
        Calendar.current.component(.month, from: Date()) - 1 // 0-based
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
            .filter { Calendar.current.component(.year, from: $0.date) == selectedYear - 1 }
            .reduce(0) { $0 + $1.amount }
    }

    private var yearTrendLabel: String? {
        guard lastYearTotal > 0, yearlyTotal > 0 else { return nil }
        let change = ((yearlyTotal - lastYearTotal) / lastYearTotal) * 100
        if change > 5 { return "Geçen yıla göre %\(Int(abs(change))) daha fazla" }
        if change < -5 { return "Geçen yıla göre %\(Int(abs(change))) daha az" }
        return "Geçen yıla benzer seviyede"
    }

    var body: some View {
        NavigationStack {
            Group {
                if allExpenses.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar.fill",
                        title: "İlk masraf kaydını ekle",
                        description: "Masraf ve bakım kayıtları ekledikçe yıllık toplam, kategori dağılımı ve km başı maliyet burada görünür.",
                        actionTitle: nil, action: nil
                    )
                } else {
                    reportContent
                }
            }
            .navigationTitle("Raporlar")
            .background(Color.appBackground)
        }
    }

    // MARK: - Content
    private var reportContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                filters

                // Hero metric — anlatısal
                PremiumMetricHero(
                    label: selectedYear == currentYear ? "Bu yıl aracın sana" : "\(String(selectedYear)) yılında aracın sana",
                    value: currencyFormat(yearlyTotal),
                    vehicleName: selectedVehicle.map { $0.plate.isEmpty ? $0.fullName : "\($0.plate) · \($0.fullName)" },
                    insightLine: yearTrendLabel
                )

                // Ownership insight cards
                insightCardsGrid

                // Monthly chart
                monthlyChart

                // Category breakdown
                categorySection

                // Top expenses
                topExpensesSection

                // Sale file CTA
                saleFileCTA

                Spacer().frame(height: AppSpacing.xxl)
            }
            .padding(.vertical, AppSpacing.md)
        }
        .background(Color.appBackground)
    }

    // MARK: - Filters
    private var filters: some View {
        HStack(spacing: AppSpacing.md) {
            if vehicles.count > 1 {
                Picker("Araç", selection: $selectedVehicleId) {
                    Text("Tüm Araçlar").tag(nil as UUID?)
                    ForEach(vehicles) { v in
                        Text(v.plate.isEmpty ? v.fullName : v.plate)
                            .tag(v.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.accentPrimary)
            }

            Picker("Yıl", selection: $selectedYear) {
                ForEach(availableYears(), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.accentPrimary)
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
            SectionHeader(title: "Aylık Dağılım")

            Chart {
                ForEach(monthlyData, id: \.month) { item in
                    BarMark(
                        x: .value("Ay", item.month),
                        y: .value("Tutar", item.total)
                    )
                    .foregroundStyle(
                        item.total > 0
                            ? AppColors.accentPrimary.opacity(0.8)
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
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Category Breakdown
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Kategori Dağılımı")

            VStack(spacing: AppSpacing.xs) {
                ForEach(categoryData.prefix(8), id: \.category) { item in
                    categoryRow(item)
                }

                if categoryData.isEmpty {
                    Text("Bu yıl için veri yok.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.md)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    private func categoryRow(_ item: (category: ExpenseCategory, total: Double, percentage: Double)) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: item.category.defaultIcon)
                    .font(.caption)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 20)

                Text(item.category.displayName)
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(currencyFormat(item.total))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.backgroundSecondary)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accentPrimary.opacity(0.6))
                        .frame(width: max(geo.size.width * CGFloat(item.percentage / 100.0), 4), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Top Expenses
    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "En Yüksek Masraflar")

            if topExpenses.isEmpty {
                Text("Bu yıl için veri yok.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
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
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
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
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amountCompactDisplay)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(expense.dateDisplay)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Sale File CTA
    private var saleFileCTA: some View {
        VStack(spacing: AppSpacing.sm) {
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
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .subtleShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
    }

    // MARK: - Helpers
    private func currencyFormat(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TRY"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: value)) ?? "₺0,00"
    }
}

// MARK: - Preview
#Preview("Raporlar — Dolu") {
    ReportsView()
        .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Raporlar — Dark Mode") {
    ReportsView()
        .modelContainer(MockDataProvider.previewContainer)
        .preferredColorScheme(.dark)
}
