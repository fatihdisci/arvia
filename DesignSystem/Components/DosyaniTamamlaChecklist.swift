import SwiftUI

// MARK: - Dosyanı Tamamla Checklist
// İlk araç eklendikten sonra Garaj'da gösterilen interaktif rehber kartı.
// Her item ilgili forma yönlendirir, pasif bilgi değil aktif aksiyon rehberidir.

struct DosyaniTamamlaChecklist: View {
    let vehicle: Vehicle
    let hasInspectionReminder: Bool
    let hasInsuranceReminder: Bool
    let hasAnyExpenseOrService: Bool
    let hasAnyDocument: Bool
    var hasMaintenancePlan: Bool = false
    var onMaintenancePlan: (() -> Void)?

    @State private var showReminderForm = false
    @State private var showServiceForm = false
    @State private var showExpenseForm = false
    @State private var showDocumentForm = false
    @State private var reminderType: ReminderType = .inspection

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(AppColors.accentPrimary)
                Text("Dosyanı tamamla")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }

            Text("Birkaç bilgi ekleyerek aracının dijital dosyasını kullanıma hazır hale getir.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, AppSpacing.xxs)

            VStack(spacing: AppSpacing.xs) {
                checklistItem(
                    icon: "car.fill",
                    title: "Araç bilgileri",
                    subtitle: "Marka, model, yıl, km, yakıt ve vites tipi",
                    done: !vehicle.brand.isEmpty && vehicle.currentOdometer > 0,
                    action: nil
                )

                checklistItem(
                    icon: "checkmark.seal",
                    title: "Muayene tarihi",
                    subtitle: "Yaklaşan muayene tarihini Yapılacaklar'a ekle",
                    done: hasInspectionReminder,
                    action: { reminderType = .inspection; showReminderForm = true }
                )

                checklistItem(
                    icon: "shield",
                    title: "Sigorta tarihi",
                    subtitle: "Trafik sigortası veya kasko tarihini ekle",
                    done: hasInsuranceReminder,
                    action: { reminderType = .trafficInsurance; showReminderForm = true }
                )

                checklistItem(
                    icon: "wrench.and.screwdriver",
                    title: "İlk bakım veya masraf",
                    subtitle: "Yaptığın bakımı veya harcamayı Geçmiş'e ekle",
                    done: hasAnyExpenseOrService,
                    action: { showServiceForm = true }
                )

                checklistItem(
                    icon: "doc.text",
                    title: "İlk belge",
                    subtitle: "Ruhsat, poliçe veya faturayı dosyana ekle",
                    done: hasAnyDocument,
                    action: { showDocumentForm = true }
                )

                checklistItem(
                    icon: "steeringwheel",
                    title: "Kişisel bakım planı",
                    subtitle: "Yapay zekâ ile sana özel bakım önerileri",
                    done: hasMaintenancePlan,
                    action: onMaintenancePlan
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(Color.appSurface)
        )
        .cardShadow()
        .padding(.horizontal, AppSpacing.screenMarginH)
        .sheet(isPresented: $showReminderForm) {
            ReminderFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showServiceForm) {
            ServiceRecordFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showExpenseForm) {
            ExpenseFormView(preselectedVehicleId: vehicle.id)
        }
        .sheet(isPresented: $showDocumentForm) {
            DocumentFormView(preselectedVehicleId: vehicle.id)
        }
    }

    private func checklistItem(
        icon: String,
        title: String,
        subtitle: String,
        done: Bool,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(done ? AppColors.success.opacity(0.12) : AppColors.backgroundSecondary)
                    .frame(width: 32, height: 32)
                if done {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(AppColors.success)
                } else {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.secondary)
                    .foregroundColor(done ? AppColors.textSecondary : AppColors.textPrimary)
                    .strikethrough(done)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            if let action, !done {
                Button {
                    action()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundColor(AppColors.accentPrimary)
                }
                .accessibilityLabel("\(title) ekle")
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }
}

#Preview("Checklist") {
    DosyaniTamamlaChecklist(
        vehicle: Vehicle(brand: "Toyota", model: "Corolla", currentOdometer: 50000),
        hasInspectionReminder: false,
        hasInsuranceReminder: true,
        hasAnyExpenseOrService: false,
        hasAnyDocument: false
    )
    .padding()
    .background(Color.appBackground)
}
