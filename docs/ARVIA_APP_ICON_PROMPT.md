# Arvia iOS App Icon — Nano Banana Prompt

> Tek seferde 5 farklı premium iOS app ikon varyantı üretmek için hazırlanmış prompt.
> Kullanım: Aşağıdaki `## PROMPT` bloğunu olduğu gibi Nano Banana'ya yapıştır.

---

## PROMPT

Generate **5 distinct premium iOS app icon variants** for **Arvia** — a vehicle history / digital car dossier app for the Turkish market. All variants share the same brand foundation but explore different visual approaches. Each variant must be clearly different from the others.

### Brand foundation (apply to ALL 5 variants)

- **Format**: 1024 × 1024 iOS app icon, square canvas, do **NOT** pre-round corners — Apple applies corner radius automatically.
- **Background**: deep dark navy, almost black, with a very subtle radial vignette (slightly darker at corners, marginally warmer near center). Suggested hex: `#0A0F1A` to `#0D1421`. **Do not** use pure `#000000`.
- **Primary color**: warm gold `#E6C479` — Arvia's `accentPrimary` token. Use this exact hue for all gold elements.
- **Gold rendering**: subtle warm highlight on the top edge of every gold element (suggests overhead light). No bottom drop shadow. No outer glow halo.
- **Negative space**: be generous — at least 35–45% of the canvas should breathe. Restrained, not maximalist.
- **Quality bar**: Apple Music, Apple Settings.app, Apple Wallet card — premium, minimalist, editorial.
- **Avoid**: blue-to-purple gradients, glassmorphism, neon glow, busy multi-element compositions, AI-slop clichés, photorealistic car illustrations, wheels, license plates, banners, ribbons, multiple text elements, drop shadows, lens flares.

### Varyant 1 — Geometric Sans-Serif "A" Monogram

A single bold uppercase letter **"A"** centered on the canvas.

- **Typography**: clean geometric sans-serif, in the spirit of Avenir Next / Inter / SF Pro Display.
  - **Uniform stroke weight** (monolinear — no contrast between thick/thin).
  - **Triangular counter** (the inner negative space of the A is a clean triangle).
  - The apex of the A is **flat-cut** (slightly squared, not sharp-pointed).
  - The crossbar is **slightly below the optical midpoint** (around 45% from the bottom) — gives it presence.
  - The two outer strokes are perfectly straight, no curvature.
- **Weight**: medium-bold. Not hairline. Not ultra-fat. The A should feel solid but elegant.
- **Color**: warm gold `#E6C479` against the dark background. Subtle warm highlight along the top edge.
- **Composition**: dead center. The A occupies roughly 45–55% of the canvas height.
- **No other element.** No ring, no dot, no underline, no second letter.

### Varyant 2 — High-Contrast Modern Serif "A" Monogram

A single uppercase letter **"A"** centered on the canvas.

- **Typography**: high-contrast modern serif, in the spirit of Didot / Bodoni.
  - **Dramatic thick-thin contrast**: the vertical strokes are notably thick; the horizontal crossbar is noticeably thin.
  - **Bracketed serifs** — subtle, refined brackets where the strokes meet the serifs (not sharp, not square). Serifs themselves are slim and elegant, not heavy.
  - The apex of the A tapers to a **sharp, refined point** (Didot-style).
  - The crossbar is positioned at the optical midpoint.
  - **Generous proportions** — slightly wider stance than the geometric A, more editorial presence.
- **Weight**: the thick verticals are bold, the thin parts are hairline. The contrast is the whole point.
- **Color**: warm gold `#E6C479`. Slightly more reflective quality than variant 1 — gold catches the light on the thick verticals.
- **Composition**: centered. The A occupies roughly 50–60% of the canvas height — a bit more presence than variant 1.
- **No other element.**

### Varyant 3 — Bold Slab-Serif "A"

A single uppercase letter **"A"** centered on the canvas.

- **Typography**: bold slab-serif, in the spirit of Rockwell / Sentinel / Lubalin Graph.
  - **Uniform thick strokes** (no thick-thin contrast — both verticals AND the crossbar are the same heavy weight).
  - **Rectangular slab serifs** at the feet of the A — flat, square, no brackets. Brutal, confident.
  - The apex of the A is **flat-cut**, horizontal — like a slab-serif A.
  - The crossbar is **thick** and positioned slightly above center.
- **Weight**: heavy. This A should feel like a manifesto's title typeface — bold, declarative, no apologies.
- **Color**: warm gold `#E6C479`.
- **Composition**: centered. Slightly smaller scale than variants 1 and 2 — the heavy weight fills more visual space, so the A should occupy about 40–50% of canvas height.
- **No other element.**

### Varyant 4 — Dossier Layer Cards

Three thin rectangular gold plates, stacked vertically with a slight offset, suggesting layered document cards (the "vehicle dossier").

- **Each plate**:
  - Thin rectangular outline, stroke width ~1.5–2 px equivalent at 1024.
  - **No fill** — only the gold border. Inside the outline is empty (dark background).
  - **Rounded corners** — very subtle, like `cornerRadius ≈ 12–16 px`. Soft, not sharp.
  - Width: roughly 55–65% of canvas width. Height: roughly 8–12% of canvas height.
- **Stacking**:
  - Three plates, **one above the other** with **small vertical gap** between them (gap ≈ 8–12 px).
  - **No horizontal offset** — they are perfectly aligned on a vertical axis (clean stack).
  - The whole stack is centered both horizontally and vertically.
- **Color**: warm gold `#E6C479` for the outlines.
- **No text, no symbols, no icons inside the plates.** Pure abstract rectangles.
- The composition evokes "stack of records", "vehicle history file", "archive cards" without being literal.

### Varyant 5 — Route / Journey Line

A single flowing gold line on the dark background, suggesting a journey or route.

- **The line**:
  - **One continuous curve** — softly S-shaped or gently arcing, NOT a zigzag, NOT a straight line.
  - Starts at the **lower-left third** of the canvas and ends at the **upper-right third** — implies forward motion, upward, "progress".
  - Stroke width: medium (~3–4 px equivalent at 1024). Consistent throughout.
  - The curve has **2–3 subtle bends** but stays elegant — never crosses itself.
- **Origin marker**:
  - At the **start** of the line (lower-left), a small **solid filled gold circle** (diameter ~5–6% of canvas). This is the "you are here" point.
- **Destination marker**:
  - At the **end** of the line (upper-right), a small **gold arrowhead** or **small open ring** (diameter ~5–6% of canvas). Indicates direction / arrival.
- **Color**: warm gold `#E6C479`.
- **Negative space**: dominant — at least 70% of the canvas is empty dark navy. The line and its two markers are the only elements.
- Evokes "your vehicle's journey", "Arvia as your road companion" — abstract, never literal map.

---

### Negative prompt (apply to all 5 variants)

blue purple gradient, glassmorphism, neon glow, rainbow colors, drop shadow, outer glow halo, busy composition, multiple letters, multiple objects, car illustration, wheels, license plate, banner ribbon, lens flare, AI artifacts, blurry edges, distorted letterforms, wrong color hue

### Output requirements

- 5 separate images, one per variant.
- Each image: 1024 × 1024 px, PNG, square.
- Maintain visual consistency across the 5 variants — same background, same gold, same negative-space restraint, same quality bar — so a viewer immediately recognizes them as one family.

---

## Varyant özet tablosu

| # | Konsept | Öğe | Konum |
|---|---|---|---|
| 1 | Geometric sans-serif A | Tek harf | Merkez |
| 2 | High-contrast serif A | Tek harf | Merkez |
| 3 | Bold slab-serif A | Tek harf | Merkez |
| 4 | Dossier katmanları | 3 dikdörtgen çerçeve | Dikey istif, merkez |
| 5 | Rota/yol çizgisi | 1 akıcı çizgi + nokta + ok | Sol-alt → sağ-üst |