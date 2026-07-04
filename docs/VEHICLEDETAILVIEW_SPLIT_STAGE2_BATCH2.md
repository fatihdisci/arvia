# VehicleDetailView.swift — Stage 2 Batch 2: Daily Quick Actions Extraction

**Tarih:** 2026-07-04
**Amaç:** `VehicleDetailView` içindeki `vehicleQuickActionsSection` + `vehicleDetailActionButton` helper'ını `VehicleQuickActionsSection` adlı bağımsız subview'a çıkarmak.

---

## 1. Oluşturulan Dosya

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/VehicleQuickActionsSection.swift` | 76 |

## 2. plutil -lint

**OK** — geçti.

## 3. Build

**BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**1504 satır** (1564 → 1504, −60 satır).

Toplamda: 2049 → 1504 (−545 satır, %27 azalma).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/InspectionReportSection.swift     ← Batch 2.1
?? Features/VehicleDetail/RecentRecordItem.swift            ← Stage 1
?? Features/VehicleDetail/RecentRecordsSection.swift        ← Batch 2.1
?? Features/VehicleDetail/SaleFilePreviewCard.swift         ← Batch 2.1
?? Features/VehicleDetail/UpcomingTaskCard.swift            ← Stage 1
?? Features/VehicleDetail/VehicleDetailMilestoneCard.swift  ← Stage 1
?? Features/VehicleDetail/VehicleQuickActionsSection.swift  ← yeni (Batch 2.2)
?? docs/ARVIA_APP_ICON_PROMPT.md                           (önceden mevcut)
?? docs/VEHICLEDETAILVIEW_SPLIT_STAGE2_BATCH1.md           ← Batch 2.1 raporu
?? docs/VEHICLEDETAILVIEW_SPLIT_STEP1.md                   ← Stage 1 raporu
```

---

## Yeni Struct

```swift
struct VehicleQuickActionsSection: View {
    let onKmUpdate: () -> Void
    let onAddExpense: () -> Void
    let onAddFuelExpense: () -> Void
    let onAddDocument: () -> Void
    let onAddReminder: () -> Void
    // ...
}
```

5 adet `@State` mutation (`showQuickKmUpdate = true` vb.) closure'a çevrildi. `@State` property'lerin sahipliği `VehicleDetailView`'da kalmaya devam ediyor.

`vehicleDetailActionButton` ismi korundu (redundant olsa da diff'i minimize etmek için).
