# ARVIA CORE EXPERIENCE REDESIGN REPORT - 2026-06-30

## Latest Commit Hash

`827868e59a4d32e50520b408a380780143ac783b`

Commit: `Redesign core Arvia experience`

## Files Changed

- `DesignSystem/Components/ArviaGuideCard.swift`
- `DesignSystem/Components/QuickActionTile.swift`
- `DesignSystem/Components/VehicleHeroHeader.swift`
- `Features/Garage/GarageView.swift`
- `Features/VehicleDetail/VehicleDetailView.swift`
- `Models/VehicleInsight.swift`
- `Services/VehicleInsightService.swift`
- `Tests/ModelTests.swift`

## What Was Changed

Executed the Phase 1 Core Experience Redesign pass focused on information architecture, premium surface design, local rule-based context filtering, and subtle SwiftUI motion polish.

No monetization behavior was changed. Pro remains limited to second and later vehicles. No backend, AI, OCR, remote push, ads, networking, or API keys were added.

## GarageView Role After Redesign

GarageView now acts as the daily vehicle pulse:

- Selected vehicle carousel remains the visual anchor.
- Hero vehicle card is more editorial and less plate-dominant.
- `Bugün Garajında` is the primary daily-priority module.
- Quick actions are compact and selected-vehicle focused.
- Garage keeps only a lightweight garage summary and no longer presents dossier-heavy sections as primary content.

Removed the prominent dossier feel from Garage by dropping the main flow placement of checklist, dossier completeness, and recent activity preview.

## VehicleDetailView Role After Redesign

VehicleDetailView is now the detailed vehicle dossier / command center:

- Richer vehicle hero section.
- Embedded vehicle-specific quick actions.
- `Bu Ay`, `Sıradaki İşler`, `Dosya Tamlığı`, `Arvia Rehber`, documents, inspection, sale file, recent records, and timeline remain concentrated here.
- Removed the extra standalone "Most Important Task" card because its reminder content duplicated `Sıradaki İşler`.

## De-duplication / Display-context Logic

Added `VehicleInsightDisplayContext`:

- `.garageDaily`
- `.vehicleDetailGuide(excludingReminderIds:)`

`garageSummary` now uses `.garageDaily`, filtering out fuel-type guidance, transmission guidance, missing-document guidance, maintenance-history prompts, and other dossier-style recommendations. Garage keeps overdue/today/upcoming/km/MTV/km-update/quiet or seasonal fallback items.

Vehicle Detail uses `.vehicleDetailGuide(excludingReminderIds:)`, passing the reminder IDs already represented by `Sıradaki İşler`. This prevents the same reminder from appearing again in `Arvia Rehber`.

## Visual Redesign Decisions

- Garage hero: larger cinematic top visual, softer automotive gradient/photo treatment, stronger vehicle identity, smaller plate treatment, refined metadata chips, and a clearer next-priority status area.
- `Bugün Garajında`: one primary highlight card plus up to two quieter secondary cards.
- Quick actions: compact surfaced buttons with circular icon wells, short labels, and minimum tap-friendly sizing.
- Vehicle detail hero: dossier label, calmer plate chip, stronger nickname/identity hierarchy, subtle entrance motion.
- `Sıradaki İşler`: soft amber-tinted surface and compact rows.
- `Dosya Tamlığı`: more meaningful progress presentation with identity/km/document chips.
- `Arvia Rehber`: guidance cards now have a distinct "Rehber notu" treatment, vertical marker, tinted surface, and softer depth.

## Motion / Interaction Improvements Added

- Garage content gets a subtle fade/slide entrance.
- Vehicle detail hero gets a subtle fade/slide entrance.
- Quick actions keep light haptic feedback and now use a pressed card style.
- Dossier score ring animation remains refined and native.
- Existing "Daha sonra" guide dismissal is preserved and visually improved.

## Quick Actions Redesign Decision

Garage quick actions were shortened to `Km`, `Masraf`, `Yakıt`, `Belge`, `Hatırlatıcı` to reduce dashboard-template feel and improve compactness.

Vehicle Detail quick actions remain vehicle-specific but are now embedded in a calmer dossier module with contextual labeling.

## Tests Added / Updated

Updated `VehicleInsightServiceTests` with coverage for:

- Garage daily context excludes fuel/transmission guidance.
- Vehicle detail guide includes richer vehicle-specific guidance.
- Vehicle detail guide excludes reminders already shown in `Sıradaki İşler`.
- Garage daily visible cards stay within the 1-3 card expectation.
- Existing Free/Pro tests still verify current MVP features remain free and only second vehicle is gated.

## Build Result

Passed.

Command:

```bash
xcodebuild -project VehicleDossierApp.xcodeproj -scheme Ruhsatim -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/ArviaCoreRedesignDerivedData -clonedSourcePackagesDirPath /private/tmp/ArviaCoreRedesignSourcePackages build
```

Result: `** BUILD SUCCEEDED **`

## Test Result

Passed.

Command:

```bash
xcodebuild -project VehicleDossierApp.xcodeproj -scheme Ruhsatim -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/ArviaCoreRedesignDerivedData -clonedSourcePackagesDirPath /private/tmp/ArviaCoreRedesignSourcePackages test
```

Result: `** TEST SUCCEEDED **`

Executed 133 tests, 0 failures.

## Manual Visual Verification Notes

Verified in simulator:

- Empty Garage state still renders cleanly.
- Seeded Garage state no longer looks like Vehicle Detail.
- Garage now reads as a daily dashboard: hero, daily priority, quick actions, small summary.
- Hero card feels more premium and plate no longer dominates the whole card.
- `Bugün Garajında` is visually differentiated and focused on the priority item.
- Dark mode rendering is clean on the captured seeded Garage screen.
- No risky App Review copy was introduced; scan only found the existing safe disclaimer.
- Free/Pro behavior unchanged by unit tests.

Limitations of manual pass:

- The available shell environment had no simulator tap/click automation utility, and `simctl` cannot tap UI elements.
- A temporary DEBUG-only seed launch hook was used only during local visual inspection and then removed before the final build/test.
- Deep Vehicle Detail navigation was code-reviewed and build/test validated, but not screenshot-captured through automated simulator navigation in this environment.

## Known Limitations

- The redesigned surfaces still use placeholder gradients when no vehicle photo exists.
- Vehicle Detail still has a long vertical dossier; Phase 2 should consider section grouping/collapsing after real-device observation.
- Dynamic Type was considered in component sizing, but broad dynamic-type screenshot capture was limited by simulator automation constraints.

## Recommended Phase 2 Follow-up

- Add lightweight UI tests or a debug-only seeded preview route for repeatable screenshot QA.
- Introduce section-level scroll polish in Vehicle Detail after measuring on real devices.
- Refine document/recent-record rows into the same premium surface family.
- Add a real visual QA matrix for light/dark and Dynamic Type sizes.
- Consider a first-run sample/demo state only for internal screenshots, kept strictly out of Release builds.

## Telegram Delivery

Telegram delivery was requested, but no Telegram CLI or connector was available in this environment. The report has been created locally at:

`ARVIA_CORE_EXPERIENCE_REDESIGN_REPORT_2026-06-30.md`
