import SwiftUI
import SwiftData

// MARK: - Garaj (Garage) Tab
// Kullanıcının araçlarını gösteren ana ekran.
// Premium araç dijital dosyası hissi: Ana araç hero kartı, hızlı işlemler,
// dosya tamlığı ve ikincil araçlar sakin bir hiyerarşide sunulur.

struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var paywallService: PaywallService
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(filter: #Predicate<Reminder> { $0.statusRaw != "completed" },
           sort: \Reminder.dueDate)
    private var activeReminders: [Reminder]

    @State private var showAddVehicle = false
    @State private var showPaywall = false
    @State private var showSettings = false
    @State private var showArchivedVehicles = false

    // QuickAction sheets
    @State private var showAddExpense = false
    @State private var showAddService = false
    @State private var showAddDocument = false
    @State private var showAddReminder = false
    @State private var showSaleFile = false
    @State private var paywallFeature: PaywallView.PaywallFeature = .secondVehicle

    private var activeVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt == nil }
    }

    private var archivedVehicles: [Vehicle] {
        vehicles.filter { $0.archivedAt != nil }
    }

    private var primaryVehicle: Vehicle? {
        activeVehicles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    emptyGarage
                } else if activeVehicles.isEmpty {
                    onlyArchivedView
                } else {
                    garageContent
                }
            }
            .navigationTitle("Garaj")
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Ayarlar")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleAddVehicle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.body)
                            .foregroundColor(AppColors.accentPrimary)
                    }
                    .accessibilityLabel("Araç Ekle")
                }

                if !archivedVehicles.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showArchivedVehicles.toggle()
                        } label: {
                            Image(systemName: "archivebox")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .accessibilityLabel("Arşivlenmiş Araçlar")
                    }
                }
            }
            .sheet(isPresented: $showAddVehicle) {
                VehicleFormView()
            }
            .sheet(isPresented: $showAddExpense) {
                ExpenseFormView(preselectedVehicleId: primaryVehicle?.id)
            }
            .sheet(isPresented: $showAddService) {
                ServiceRecordFormView(preselectedVehicleId: primaryVehicle?.id)
            }
            .sheet(isPresented: $showAddDocument) {
                DocumentFormView(preselectedVehicleId: primaryVehicle?.id)
            }
            .sheet(isPresented: $showAddReminder) {
                ReminderFormView(preselectedVehicleId: primaryVehicle?.id)
            }
            .sheet(isPresented: $showSaleFile) {
                if let vehicle = primaryVehicle {
                    SaleFileView(vehicle: vehicle)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: paywallFeature)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Empty State
    private var emptyGarage: some View {
        EmptyStateView(
            icon: "car",
            title: "İlk aracının dosyasını oluşturalım",
            description: "Muayene, sigorta, bakım ve belgeleri tek yerde takip etmek için aracını ekle.",
            actionTitle: "Araç Ekle",
            action: { handleAddVehicle() }
        )
    }

    // MARK: - Only Archived
    private var onlyArchivedView: some View {
        VStack(spacing: AppSpacing.lg) {
            EmptyStateView(
                icon: "archivebox",
                title: "Tüm araçlar arşivlenmiş",
                description: "Yeni bir araç ekleyebilir veya arşivlenmiş araçları görüntüleyebilirsin.",
                actionTitle: "Araç Ekle",
                action: { handleAddVehicle() }
            )

            if !archivedVehicles.isEmpty {
                archivedSection
            }
        }
    }

    // MARK: - Main Garage Content
    private var garageContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 1. Hero Vehicle Card
                if let vehicle = primaryVehicle {
                    heroSection(vehicle: vehicle)
                }

                // 2. Quick Action Rail
                quickActionRail

                // 3. Dossier Completeness
                if let vehicle = primaryVehicle {
                    DossierCompletenessCard(
                        score: computeFileScore(for: vehicle),
                        criteriaMet: criteriaMet(for: vehicle),
                        criteriaMissing: criteriaMissing(for: vehicle)
                    )
                    .padding(.horizontal, AppSpacing.screenMarginH)
                }

                // 4. Recent activity preview
                if let vehicle = primaryVehicle {
                    recentActivitySection(vehicle: vehicle)
                }

                // 5. Secondary vehicles
                if activeVehicles.count > 1 {
                    secondaryVehiclesSection
                }

                // 6. Archived vehicles
                if !archivedVehicles.isEmpty {
                    archivedSection
                }

                Spacer().frame(height: AppSpacing.xxl)
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - Hero Section
    private func heroSection(vehicle: Vehicle) -> some View {
        NavigationLink {
            VehicleDetailView(vehicle: vehicle)
        } label: {
            VStack(spacing: 0) {
                // Photo placeholder
                ZStack {
                    LinearGradient(
                        colors: [
                            AppColors.vehicle,
                            AppColors.vehicle.opacity(0.6),
                            AppColors.accentPrimary.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "car.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(height: 140)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: AppRadius.heroCard,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: AppRadius.heroCard
                    )
                )

                // Info section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    // Plate capsule
                    Text(vehicle.plate.isEmpty ? "—" : vehicle.plate)
                        .plateTextStyle()
                        .foregroundColor(AppColors.textPrimary)

                    // Brand + Model + Year
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Text(vehicle.fullName)
                            .font(AppTypography.sectionTitle)
                            .foregroundColor(AppColors.textPrimary)

                        if let year = vehicle.year {
                            Text("·")
                                .foregroundColor(AppColors.textTertiary)
                            Text(String(year))
                                .font(AppTypography.cardTitle)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Info badges
                    HStack(spacing: AppSpacing.sm) {
                        infoBadge(icon: "gauge.with.needle", text: vehicle.odometerDisplay)
                        infoBadge(icon: "fuelpump", text: vehicle.fuelType.displayName)
                        if let trans = vehicle.transmissionType {
                            infoBadge(
                                icon: trans == .automatic ? "a.circle" : "m.circle",
                                text: trans.displayName
                            )
                        }
                    }

                    // Nickname + upcoming
                    HStack {
                        if !vehicle.nickname.isEmpty {
                            HStack(spacing: AppSpacing.xxs) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.accentPrimary)
                                Text(vehicle.nickname)
                                    .font(AppTypography.secondary)
                                    .foregroundColor(AppColors.accentPrimary)
                            }
                        }

                        Spacer()

                        if let reminder = upcomingReminder(for: vehicle) {
                            HStack(spacing: 4) {
                                Image(systemName: reminder.isOverdue ? "exclamationmark.triangle.fill" : "bell.fill")
                                    .font(.caption2)
                                    .foregroundColor(reminder.isOverdue ? AppColors.critical : AppColors.warning)
                                Text(reminder.title)
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(reminder.isOverdue ? AppColors.critical : AppColors.warning)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.heroCard)
                    .fill(Color.appSurface)
            )
            .elevatedShadow()
        }
        .buttonStyle(PlainCardButtonStyle())
        .padding(.horizontal, AppSpacing.screenMarginH)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(vehicle.plate), \(vehicle.fullName), \(vehicle.odometerDisplay)")
    }

    private func infoBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(AppTypography.captionMedium)
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(AppColors.backgroundSecondary)
        )
    }

    // MARK: - Quick Action Rail
    private var quickActionRail: some View {
        QuickActionRail(actions: [
            .init(icon: "turkishlirasign.circle", label: "Masraf", color: AppColors.accentPrimary) {
                showAddExpense = true
            },
            .init(icon: "wrench.and.screwdriver", label: "Bakım", color: AppColors.warning) {
                showAddService = true
            },
            .init(icon: "doc.text.viewfinder", label: "Belge", color: AppColors.document) {
                if paywallService.canAddDocument(currentCount: allDocumentsCount) {
                    showAddDocument = true
                } else {
                    paywallFeature = .documentLimit
                    showPaywall = true
                }
            },
            .init(icon: "bell.badge", label: "Hatırlatıcı", color: AppColors.vehicle) {
                showAddReminder = true
            },
            .init(icon: "doc.richtext", label: "Satış", color: AppColors.success) {
                if paywallService.canCreateSaleFile() {
                    showSaleFile = true
                } else {
                    paywallFeature = .saleFile
                    showPaywall = true
                }
            },
        ])
    }

    /// Tüm dökümanları sayar (paywall limit kontrolü için).
    private var allDocumentsCount: Int {
        (try? modelContext.fetch(FetchDescriptor<VehicleDocument>()))?.count ?? 0
    }

    // MARK: - Recent Activity
    private func recentActivitySection(vehicle: Vehicle) -> some View {
        let recentItems = recentRecords(for: vehicle)
        if recentItems.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Son İşlemler")

                VStack(spacing: 0) {
                    ForEach(Array(recentItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: item.icon)
                                .font(.subheadline)
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
                        .padding(.vertical, AppSpacing.sm)

                        if index < min(recentItems.count, 3) - 1 {
                            Divider()
                                .padding(.leading, 44)
                                .padding(.trailing, AppSpacing.screenMarginH)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color.appSurface)
                )
                .subtleShadow()
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
        )
    }

    // MARK: - Secondary Vehicles
    private var secondaryVehiclesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "Diğer Araçlar")

            ForEach(activeVehicles.dropFirst()) { vehicle in
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(AppColors.vehicle.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "car")
                                .font(.subheadline)
                                .foregroundColor(AppColors.vehicle)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimary)
                            Text(vehicle.fullName)
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
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.appSurface)
                    )
                }
                .buttonStyle(PlainCardButtonStyle())
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
        }
    }

    // MARK: - Archived Section
    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            DisclosureGroup(isExpanded: $showArchivedVehicles) {
                ForEach(archivedVehicles) { vehicle in
                    NavigationLink {
                        VehicleDetailView(vehicle: vehicle)
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(AppColors.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.plate.isEmpty ? vehicle.fullName : vehicle.plate)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Arşivlendi: \(vehicle.archivedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "archivebox")
                        .foregroundColor(AppColors.textTertiary)
                    Text("Arşivlenmiş Araçlar")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text("(\(archivedVehicles.count))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.screenMarginH)
        }
    }

    // MARK: - Actions
    private func handleAddVehicle() {
        if paywallService.canAddVehicle(currentCount: activeVehicles.count) {
            showAddVehicle = true
        } else {
            paywallFeature = .secondVehicle
            showPaywall = true
        }
    }

    // MARK: - Helpers
    private func upcomingReminder(for vehicle: Vehicle) -> Reminder? {
        let reminders = activeReminders.filter { $0.vehicleId == vehicle.id }
        if let overdue = reminders.first(where: { $0.isOverdue }) { return overdue }
        if let today = reminders.first(where: { $0.isToday }) { return today }
        return reminders
            .filter { $0.dueDate != nil && !$0.isOverdue }
            .min(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
    }

    private func computeFileScore(for vehicle: Vehicle) -> Int {
        var score = 0
        if !vehicle.brand.isEmpty { score += 10 }
        if !vehicle.model.isEmpty { score += 10 }
        if vehicle.year != nil { score += 10 }
        if vehicle.currentOdometer > 0 { score += 10 }
        if vehicle.transmissionType != nil { score += 10 }
        if vehicle.purchaseDate != nil { score += 10 }
        if vehicle.purchasePrice != nil { score += 10 }
        let vehReminders = activeReminders.filter { $0.vehicleId == vehicle.id }
        if !vehReminders.isEmpty { score += 15 }
        if !vehReminders.contains(where: { $0.isOverdue }) { score += 15 }
        if !recentExpenses(for: vehicle).isEmpty { score += 5 }
        if !recentServices(for: vehicle).isEmpty { score += 5 }
        return min(score, 100)
    }

    private func recentExpenses(for vehicle: Vehicle) -> [Expense] {
        (try? modelContext.fetch(FetchDescriptor<Expense>()))?.filter { $0.vehicleId == vehicle.id } ?? []
    }

    private func recentServices(for vehicle: Vehicle) -> [ServiceRecord] {
        (try? modelContext.fetch(FetchDescriptor<ServiceRecord>()))?.filter { $0.vehicleId == vehicle.id } ?? []
    }

    private func criteriaMet(for vehicle: Vehicle) -> [String] {
        var met: [String] = []
        if !vehicle.brand.isEmpty { met.append("Marka") }
        if !vehicle.model.isEmpty { met.append("Model") }
        if vehicle.year != nil { met.append("Yıl") }
        if vehicle.currentOdometer > 0 { met.append("Km") }
        if vehicle.transmissionType != nil { met.append("Vites") }
        return met
    }

    private func criteriaMissing(for vehicle: Vehicle) -> [String] {
        var missing: [String] = []
        if vehicle.brand.isEmpty { missing.append("Marka") }
        if vehicle.model.isEmpty { missing.append("Model") }
        if vehicle.year == nil { missing.append("Yıl") }
        if vehicle.currentOdometer == 0 { missing.append("Km") }
        if vehicle.transmissionType == nil { missing.append("Vites") }
        return missing
    }

    private struct RecentRecordItem: Identifiable {
        let id: UUID
        let icon: String
        let title: String
        let subtitle: String
        let date: Date
    }

    private func recentRecords(for vehicle: Vehicle) -> [RecentRecordItem] {
        var items: [RecentRecordItem] = []
        for e in recentExpenses(for: vehicle) {
            items.append(RecentRecordItem(id: e.id, icon: e.category.defaultIcon, title: e.category.displayName, subtitle: e.amountCompactDisplay, date: e.date))
        }
        for s in recentServices(for: vehicle) {
            items.append(RecentRecordItem(id: s.id, icon: "wrench.and.screwdriver", title: s.serviceType.displayName, subtitle: s.vendorName ?? s.totalCostDisplay ?? "", date: s.date))
        }
        return items.sorted { $0.date > $1.date }
    }
}

// MARK: - Plain Card Button Style
// Kart şeklindeki butonlarda varsayılan buton animasyonu yerine
// hafif opacity değişimi kullanır.
struct PlainCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
@MainActor
private func emptyPreviewContainer() -> ModelContainer {
    let schema = Schema([Vehicle.self, Reminder.self, Expense.self,
                         ServiceRecord.self, PartChange.self,
                         VehicleDocument.self, InspectionReport.self,
                         SaleFile.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: config)
}

#Preview("Garaj — Boş") {
    GarageView()
        .modelContainer(emptyPreviewContainer())
}

#Preview("Garaj — Araçlar") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
}

#Preview("Garaj — Dark Mode") {
    GarageView()
        .modelContainer(MockDataProvider.previewContainer)
        .preferredColorScheme(.dark)
}
