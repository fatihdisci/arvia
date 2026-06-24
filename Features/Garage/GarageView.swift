import SwiftUI
import SwiftData

// MARK: - Garaj (Garage) Tab
// Kullanıcının araçlarını gösteren ana ekran.
// Araç yoksa EmptyStateView, varsa araç kartları listesi.

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

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    emptyGarage
                } else {
                    vehicleList
                }
            }
            .navigationTitle("Garaj")
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Ayarlar")
                }

                if !vehicles.isEmpty {
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
                }
            }
            .sheet(isPresented: $showAddVehicle) {
                VehicleFormView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: .secondVehicle)
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

    // MARK: - Actions
    private func handleAddVehicle() {
        if paywallService.canAddVehicle(currentCount: vehicles.count) {
            showAddVehicle = true
        } else {
            showPaywall = true
        }
    }

    // MARK: - Vehicle List
    private var vehicleList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                // Header
                SectionHeader(
                    title: "Araçlarım",
                    actionTitle: vehicles.count > 1 ? "\(vehicles.count) araç" : nil,
                    action: nil
                )

                // Vehicle cards — NavigationLink ile detay ekranına
                ForEach(vehicles) { vehicle in
                    NavigationLink {
                        VehicleDetailView(vehicle: vehicle)
                    } label: {
                        VehicleCard(
                            vehicle: vehicle,
                            upcomingReminderTitle: upcomingReminder(for: vehicle)?.title,
                            upcomingReminderStatus: upcomingReminder(for: vehicle)?.status,
                            fileCompletenessScore: computeFileScore(for: vehicle)
                        )
                    }
                    .buttonStyle(PlainCardButtonStyle())
                }
                .padding(.bottom, AppSpacing.xxl)
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - Helpers
    private func upcomingReminder(for vehicle: Vehicle) -> Reminder? {
        let reminders = activeReminders.filter { $0.vehicleId == vehicle.id }

        // Önce gecikmiş olanı göster
        if let overdue = reminders.first(where: { $0.isOverdue && $0.statusRaw != ReminderStatus.completed.rawValue }) {
            return overdue
        }
        // Sonra bugün olanı
        if let today = reminders.first(where: { $0.isToday }) {
            return today
        }
        // Sonra en yakın olanı
        return reminders
            .filter { $0.dueDate != nil && !$0.isOverdue }
            .min(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) })
    }

    /// Basit dosya tamlık skoru (0-100).
    /// Kriterler: genel bilgiler, yaklaşan iş durumu, km güncelliği.
    private func computeFileScore(for vehicle: Vehicle) -> Int {
        var score = 0

        // Temel bilgiler (max 40)
        if !vehicle.brand.isEmpty { score += 10 }
        if !vehicle.model.isEmpty { score += 10 }
        if vehicle.year != nil { score += 10 }
        if vehicle.currentOdometer > 0 { score += 10 }

        // Detay bilgiler (max 30)
        if vehicle.transmissionType != nil { score += 10 }
        if vehicle.purchaseDate != nil { score += 10 }
        if vehicle.purchasePrice != nil { score += 10 }

        // Reminder durumu (max 30)
        let reminders = activeReminders.filter { $0.vehicleId == vehicle.id }
        if !reminders.isEmpty { score += 15 }
        if !reminders.contains(where: { $0.isOverdue }) { score += 15 }

        return min(score, 100)
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
