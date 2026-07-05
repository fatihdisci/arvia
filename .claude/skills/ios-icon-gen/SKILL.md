---
name: ios-icon-gen
description: Generate iOS app icons, tab bar icons, and SF Symbol recommendations for SwiftUI projects.
metadata:
  project: arvia
---

# iOS Icon Generation

## When to Activate

- Choosing tab bar / toolbar icons
- Picking SF Symbols for navigation, actions, or status indicators
- Ensuring icon consistency across the app
- Evaluating symbol legibility at small sizes (tab bar = 25pt)

## Process

1. **Understand context** — what does this icon communicate? What are the sibling icons?
2. **Search SF Symbols** — find 5-8 candidates in the same visual weight class
3. **Evaluate candidates**:
   - Legibility at target size (tab bar: 25pt, toolbar: 22pt, nav: 17pt)
   - Visual weight consistency with sibling icons
   - Semantic clarity — does it mean what you think it means?
   - Dark mode appearance (always dark in this app)
4. **Recommend** — top 2-3 with tradeoffs noted

## Project Icons Inventory

| Location | Icon | Size |
|----------|------|------|
| Tab: Garaj | `car` | 25pt |
| Tab: Asistan | `steeringwheel` | 25pt |
| Tab: Yapılacaklar | `checklist` | 25pt |
| Tab: Kayıtlar | `tray.full` | 25pt |
| Tab: Topluluk | `person.3` | 25pt |

## SF Symbol Selection Rules

- Match visual weight: prefer consistent line weight across tab bar
- Avoid overly detailed symbols at small sizes
- Test with `.font(.body)` for tab bar rendering
- Prefer Apple-recommended symbols for common actions
- Dark background: ensure symbol has enough contrast against AMOLED black