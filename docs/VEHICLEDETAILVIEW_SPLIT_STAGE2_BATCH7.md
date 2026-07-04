# VehicleDetailView.swift — Stage 2 Batch 7: Detail Hero + File Score Card (FINAL BATCH)

**Tarih:** 2026-07-04
**Amaç:** Son iki section'ı (`VehicleDetailHero` + `FileCompletenessCard`) bağımsız subview'lara çıkarmak. Bu batch ile VehicleDetailView.swift split çalışması tamamlanmıştır.

---

## 1. Oluşturulan Dosyalar (Bu Batch)

| # | Dosya | Satır |
|---|-------|-------|
| 1 | `Features/VehicleDetail/VehicleDetailHero.swift` | 204 |
| 2 | `Features/VehicleDetail/FileCompletenessCard.swift` | 79 |

## 2. plutil -lint

Her pbxproj düzenlemesinden sonra geçti: **2/2 OK**.

## 3. Build

- Step A (VehicleDetailHero): **BUILD SUCCEEDED**
- Step B (FileCompletenessCard): **BUILD SUCCEEDED**

## 4. Test Sonucu

**151/151 passed** — 0 failures.

## 5. VehicleDetailView.swift

**540 satır** (810 → 540, −270 satır).

Toplamda: 2049 → 540 (−1509 satır, **%74 azalma**).

## 6. git status

```
 M App/VehicleDossierApp.swift                              (önceden mevcut)
 D Features/Garage/VehicleFormView.swift                    (önceden mevcut)
 M Features/Garage/VehicleWizardView.swift                  (önceden mevcut)
 M Features/VehicleDetail/VehicleDetailView.swift           ← bu task
 M VehicleDossierApp.xcodeproj/project.pbxproj              ← bu task
?? DesignSystem/Components/QuickOdometerUpdateSheet.swift   ← Stage 1
?? Features/VehicleDetail/ArviaGuideSection.swift           ← Batch 2.6
?? Features/VehicleDetail/ContextualInsightCompactCard.swift ← Stage 1
?? Features/VehicleDetail/CurrentStatusSection.swift        ← Batch 2.5
?? Features/VehicleDetail/DocumentsSection.swift            ← Batch 2.4
?? Features/VehicleDetail/FileCompletenessCard.swift        ← yeni (Batch 2.7)
?? Features/VehicleDetail/InspectionReportSection.swift     ← Batch 2.1
?? Features/VehicleDetail/LifeTimelineSection.swift         ← Batch 2.3
?? Features/VehicleDetail/RecentRecordItem.swift            ← Stage 1
?? Features/VehicleDetail/RecentRecordsSection.swift        ← Batch 2.1
?? Features/VehicleDetail/SaleFilePreviewCard.swift         ← Batch 2.1
?? Features/VehicleDetail/UpcomingTaskCard.swift            ← Stage 1
?? Features/VehicleDetail/VehicleDetailHero.swift           ← yeni (Batch 2.7)
?? Features/VehicleDetail/VehicleDetailMilestoneCard.swift  ← Stage 1
?? Features/VehicleDetail/VehicleQuickActionsSection.swift  ← Batch 2.2
```

---

## Parent'ta Kalanlar (Doğrulandı)

| Üye | Durum |
|-----|-------|
| `computeFileScore()` | Intact, line 397 |
| `scoreColor(_:)` | Intact, line 429 (dead code, korundu) |
| `notificationRouteBanner` | Intact, line 313 |
| `upcomingTaskEmptyState` | Intact, line 371 (dead code, korundu) |
| `handleGuideAction` | Intact |
| `handleGuideInsightDismiss` | Intact (Batch 2.6'da eklendi) |

---

## Tüm Split Çalışması Özeti

| Aşama | Batch | Önce (satır) | Sonra (satır) | Delta | Oluşturulan Dosyalar |
|-------|-------|-------------|--------------|-------|---------------------|
| **Stage 1** | — | 2049 | 1805 | −244 | QuickOdometerUpdateSheet (76), UpcomingTaskCard (25), ContextualInsightCompactCard (26), RecentRecordItem (7), VehicleDetailMilestoneCard (118) |
| **Stage 2** | 2.1 | 1805 | 1564 | −241 | SaleFilePreviewCard (50), RecentRecordsSection (116), InspectionReportSection (94) |
| | 2.2 | 1564 | 1504 | −60 | VehicleQuickActionsSection (76) |
| | 2.3 | 1504 | 1204 | −300 | LifeTimelineSection (316) |
| | 2.4 | 1204 | 1050 | −154 | DocumentsSection (169) |
| | 2.5 | 1050 | 873 | −177 | CurrentStatusSection (192) |
| | 2.6 | 873 | 810 | −63 | ArviaGuideSection (81) |
| | 2.7 | 810 | **540** | −270 | VehicleDetailHero (204), FileCompletenessCard (79) |
| **Toplam** | | **2049** | **540** | **−1509 (%74)** | **16 yeni dosya** |

### Oluşturulan Tüm Dosyalar (15 adet)

**Stage 1 (5 dosya):**
1. `DesignSystem/Components/QuickOdometerUpdateSheet.swift` — 76 satır
2. `Features/VehicleDetail/UpcomingTaskCard.swift` — 25 satır
3. `Features/VehicleDetail/ContextualInsightCompactCard.swift` — 26 satır
4. `Features/VehicleDetail/RecentRecordItem.swift` — 7 satır
5. `Features/VehicleDetail/VehicleDetailMilestoneCard.swift` — 118 satır

**Stage 2 (10 dosya):**
6. `Features/VehicleDetail/SaleFilePreviewCard.swift` — 50 satır
7. `Features/VehicleDetail/RecentRecordsSection.swift` — 116 satır
8. `Features/VehicleDetail/InspectionReportSection.swift` — 94 satır
9. `Features/VehicleDetail/VehicleQuickActionsSection.swift` — 76 satır
10. `Features/VehicleDetail/LifeTimelineSection.swift` — 316 satır
11. `Features/VehicleDetail/DocumentsSection.swift` — 169 satır
12. `Features/VehicleDetail/CurrentStatusSection.swift` — 192 satır
13. `Features/VehicleDetail/ArviaGuideSection.swift` — 81 satır
14. `Features/VehicleDetail/VehicleDetailHero.swift` — 204 satır
15. `Features/VehicleDetail/FileCompletenessCard.swift` — 79 satır

Toplam yeni kod: ~1800 satır (16 dosyaya dağıtıldı).
