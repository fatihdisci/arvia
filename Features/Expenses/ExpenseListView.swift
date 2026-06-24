import SwiftUI
import SwiftData

// MARK: - Expense List View
// Tüm araçlara ait masrafların listesi, toplamlar ve kategori dağılımı.

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var showAddExpense = false
    @State private var editingExpense: Expense?

    // Filtre
    @State private var selectedVehicleFilter: UUID?

    private var filteredExpenses: [Expense] {
        if let vehicleId = selectedVehicleFilter {
            return allExpenses.filter { $0.vehicleId == vehicleId }
        }
        return allExpenses
    }

    // Toplamlar
    private var yearlyTotal: Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        return filteredExpenses
            .filter { Calendar.current.component(.year, from: $0.date) == currentYear }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyTotal: Double {
        let now = Date()
        let currentMonth = Calendar.current.component(.month, from: now)
        let currentYear = Calendar.current.component(.year, from: now)
        return filteredExpenses
            .filter {
                let comps = Calendar.current.dateComponents([.year, .month], from: $0.date)
                return comps.year == currentYear && comps.month == currentMonth
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var categoryTotals: [(ExpenseCategory, Double)] {
        var dict: [ExpenseCategory: Double] = [:]
        for expense in filteredExpenses {
            dict[expense.category, default: 0] += expense.amount
        }
        return dict
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        Group {
            if allExpenses.isEmpty {
                emptyState
            } else {
                expenseListContent
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView(
            icon: "list.bullet.rectangle",
            title: "İlk masraf kaydını ekle",
            description: "Yakıt, bakım, parça ve sigorta giderlerini kaydederek aracının yıllık maliyetini gör.",
            actionTitle: "Masraf Ekle",
            action: { showAddExpense = true }
        )
    }

    // MARK: - List Content
    private var expenseListContent: some View {
        List {
            // Filtre
            if vehicles.count > 1 {
                Section {
                    Picker("Araç", selection: $selectedVehicleFilter) {
                        Text("Tüm Araçlar").tag(nil as UUID?)
                        ForEach(vehicles) { v in
                            Text(v.plate.isEmpty ? v.fullName : "\(v.plate) — \(v.fullName)")
                                .tag(v.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(Color.appSurface)
            }

            // Toplamlar
            Section {
                totalsGrid
            } header: {
                Text("Özet")
            }
            .listRowBackground(Color.appSurface)

            // Kategori dağılımı
            if !categoryTotals.isEmpty {
                Section {
                    ForEach(categoryTotals, id: \.0) { category, total in
                        categoryRow(category: category, total: total)
                    }
                } header: {
                    Text("Kategori Dağılımı")
                }
                .listRowBackground(Color.appSurface)
            }

            // Liste
            Section {
                if filteredExpenses.isEmpty {
                    Text("Bu filtrede masraf bulunamadı.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ForEach(filteredExpenses) { expense in
                        expenseRow(expense)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(expense)
                                    try? modelContext.save()
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Text("Masraflar\(filteredExpenses.isEmpty ? "" : " · \(filteredExpenses.count)")")
            }
            .listRowBackground(Color.appSurface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }

    // MARK: - Totals Grid
    private var totalsGrid: some View {
        HStack(spacing: AppSpacing.md) {
            totalCard(
                title: "Bu Ay",
                amount: monthlyTotal,
                color: AppColors.accentPrimary
            )
            totalCard(
                title: "Bu Yıl",
                amount: yearlyTotal,
                color: AppColors.vehicle
            )
        }
    }

    private func totalCard(title: LocalizedStringKey, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(currencyFormat(amount))
                .font(AppTypography.amount)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - Category Row
    private func categoryRow(category: ExpenseCategory, total: Double) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: category.defaultIcon)
                .font(.body)
                .foregroundColor(AppColors.accentPrimary)
                .frame(width: 24)

            Text(category.displayName)
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(currencyFormat(total))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    // MARK: - Expense Row
    private func expenseRow(_ expense: Expense) -> some View {
        Button {
            editingExpense = expense
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: expense.category.defaultIcon)
                    .font(.body)
                    .foregroundColor(AppColors.accentPrimary)
                    .frame(width: 28)

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
        }
        .buttonStyle(.plain)
        .sheet(item: $editingExpense) { expense in
            ExpenseFormView(existingExpense: expense)
        }
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
#Preview("Masraf Listesi — Dolu") {
    ExpenseListView()
        .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Masraf Listesi — Dark") {
    ExpenseListView()
        .modelContainer(MockDataProvider.previewContainer)
        .preferredColorScheme(.dark)
}
