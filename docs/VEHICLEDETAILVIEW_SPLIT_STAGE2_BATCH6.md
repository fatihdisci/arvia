# VehicleDetailView.swift — Stage 2 Batch 6: Arvia Rehber Section Extraction

**Tarih:** 2026-07-04
**Amaç:** `VehicleDetailView` içindeki `arviaGuideSection` + `arviaGuideDisclaimer`'ı `ArviaGuideSection` adlı bağımsız subview'a çıkarmak.

---

## 1. Oluşturulan Dosya

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/ArviaGuideSection.swift` | 81 |

## 2. plutil -lint

**OK** — geçti.

## 3. Build

**BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**810 satır** (873 → 810, −63 satır).

Toplamda: 2049 → 810 (−1239 satır, %60 azalma).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ArviaGuideSection.swift           ← yeni (Batch 2.6)
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/CurrentStatusSection.swift        ← Batch 2.5
?? Features/VehicleDetail/DocumentsSection.swift            ← Batch 2.4
?? Features/VehicleDetail/InspectionReportSection.swift     ← Batch 2.1
?? Features/VehicleDetail/LifeTimelineSection.swift         ← Batch 2.3
?? Features/VehicleDetail/RecentRecordItem.swift            ← Stage 1
?? Features/VehicleDetail/RecentRecordsSection.swift        ← Batch 2.1
?? Features/VehicleDetail/SaleFilePreviewCard.swift         ← Batch 2.1
?? Features/VehicleDetail/UpcomingTaskCard.swift            ← Stage 1
?? Features/VehicleDetail/VehicleDetailMilestoneCard.swift  ← Stage 1
?? Features/VehicleDetail/VehicleQuickActionsSection.swift  ← Batch 2.2
?? docs/ARVIA_APP_ICON_PROMPT.md                           (önceden mevcut)
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH1.md           ← Batch 2.1 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH2.md           ← Batch 2.2 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH3.md           ← Batch 2.3 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH4.md           ← Batch 2.4 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH5.md           ← Batch 2.5 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STEP1.md                   ← Stage 1 raporu
```

---

## Yeni Struct

```swift
struct ArviaGuideSection: View {
    let insights: [VehicleInsight]
    let vehicleId: UUID
    let onAction: (VehicleInsightAction) -> Void
    let onDismissInsight: (VehicleInsight) -> Void
    // ...
}
```

## Parent'a Eklenen Yeni Method

`handleGuideInsightDismiss(_:)` — eski inline `onDismiss` closure'ının birebir aynısı, `handleGuideAction`'ın hemen altına eklendi. Logic değişmedi.

## Doğrulama

- `handleGuideAction`: **korundu** — `VehicleDetailView.swift` line 467'de duruyor, değişmedi.
- `handleGuideInsightDismiss`: **eklendi** — `VehicleDetailView.swift` line 494'te.
