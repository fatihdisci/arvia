import SwiftUI

// MARK: - Demo Timeline Event
// Boş state onboarding için örnek yaşam çizgisi olayı.
struct DemoTimelineEvent: Identifiable {
    let id = UUID()
    let kind: VehicleDetailMilestoneCard.MilestoneKind
    let title: String
    let subtitle: String?
    let dateRelative: String
    let icon: String

    static let onboardingSamples: [DemoTimelineEvent] = [
        DemoTimelineEvent(
            kind: .purchase,
            title: "Satın Alma",
            subtitle: "₺850.000",
            dateRelative: "Eyl 2022",
            icon: "cart.fill"
        ),
        DemoTimelineEvent(
            kind: .majorService,
            title: "İlk Büyük Bakım",
            subtitle: "Triger seti + yağ değişimi · ₺14.500",
            dateRelative: "Mar 2023",
            icon: "wrench.and.screwdriver.fill"
        ),
        DemoTimelineEvent(
            kind: .inspection,
            title: "Ekspertiz Raporu",
            subtitle: "TÜVTÜRK · 95.000 km",
            dateRelative: "Haz 2025",
            icon: "checkmark.seal.fill"
        )
    ]
}

// MARK: - Vehicle Life Timeline
// Aracın kronolojik yaşam çizgisi — uygulamanın imza etkileşimi.
// Karar 3.3: Milestone event'ler ayrıcalıklı kart olarak gösterilir,
// regular event'ler mevcut sade liste halini korur.
// Faz 1.1: Boş state onboarding mock — 3 örnek event + CTA.
struct LifeTimelineSection: View {
    let vehicle: Vehicle
    let serviceRecords: [ServiceRecord]
    let expenses: [Expense]
    let inspectionReports: [InspectionReport]
    let saleFiles: [SaleFile]
    let onAddFirstRecord: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            let allEvents = buildTimelineEvents()
            let milestoneEvents = allEvents.filter { $0.isMilestone }
            let regularEvents = allEvents.filter { !$0.isMilestone }
            let hasNoRealData = milestoneEvents.isEmpty && regularEvents.isEmpty

            // Header — boş state'te "ÖRNEK" rozeti
            HStack(spacing: AppSpacing.xs) {
                SectionHeader(title: "Araç Yaşam Çizgisi")

                if hasNoRealData {
                    // Nötr bilgi rozeti — warning rengi "dikkat" demek, örnek veri değil.
                    Text("ÖRNEK")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            Capsule()
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }
            }

            VStack(spacing: AppSpacing.md) {
                if hasNoRealData {
                    // Demo timeline (örnek görünüm)
                    ForEach(Array(DemoTimelineEvent.onboardingSamples.enumerated()), id: \.element.id) { index, demo in
                        demoTimelineItem(event: demo, isFirst: index == 0, isLast: index == DemoTimelineEvent.onboardingSamples.count - 1)
                    }

                    Divider()
                        .padding(.vertical, AppSpacing.xs)

                    // "Henüz kayıt yok" placeholder
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

                    // CTA: İlk Kaydı Ekle
                    if let onAddFirstRecord {
                        addFirstRecordCTA(action: onAddFirstRecord)
                    }
                } else {
                    // Mevcut davranış: gerçek veri gösterimi

                    // Milestone kartları
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
                    if !milestoneEvents.isEmpty && !regularEvents.isEmpty {
                        Divider()
                            .padding(.vertical, AppSpacing.xxs)
                    }

                    // Regular timeline items
                    let recentRegulars = Array(regularEvents.suffix(8))
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

            // Disclaimer — boş state'te güncellenmiş metin
            if hasNoRealData {
                Text("Böyle görünecek. İlk kaydı eklediğinde kendi geçmişin oluşmaya başlar.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.screenMarginH + AppSpacing.md)
            } else if serviceRecords.isEmpty && inspectionReports.isEmpty {
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

    // MARK: - Demo Timeline Item (örnek görünüm)
    private func demoTimelineItem(event: DemoTimelineEvent, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Sol kolon: çizgi + ikon
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(event.kind.defaultAccent.opacity(0.5))
                        .frame(width: 1.5, height: 12)
                } else {
                    Spacer().frame(height: 4)
                }
                Image(systemName: event.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(event.kind.defaultAccent.opacity(0.85)))
                    .overlay(Circle().stroke(event.kind.defaultAccent.opacity(0.35), lineWidth: 1))
                if !isLast {
                    Rectangle()
                        .fill(AppColors.border.opacity(0.5))
                        .frame(width: 1.5, height: 16)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .frame(width: 30)

            // Sağ kolon: title + subtitle + date
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer()
                Text(event.dateRelative)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(AppSpacing.xs)
        .frame(minHeight: 44)
        // Hedef: görünür ama "örnek olduğu belli" — silik placeholder değil.
        .opacity(0.72)
    }

    // MARK: - "İlk Kaydı Ekle" CTA
    private func addFirstRecordCTA(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundColor(AppColors.accentPrimary)
                Text("İlk Kaydı Ekle")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.accentPrimary)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.accentPrimary)
            }
            .padding(AppSpacing.md)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.accentPrimary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.accentPrimary.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Build Timeline Events
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
            if isMajor { continue }
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

    // MARK: - Timeline Item
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
}
