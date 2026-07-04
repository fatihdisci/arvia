# DESIGN.md — Arvia Premium Tasarım Anayasası

## 1. Ürün karakteri

Bu uygulama premium, güvenilir, teknik ve odaklı görünmelidir.
Tasarım konsepti: **"Aracın Dijital Pasaportu"** — aracının finansal ve teknik dosyası, dijital kokpit hassasiyetiyle sunulur.

Uygulama dili:

- Araç takip defteri değil.
- Ucuz oto sanayi uygulaması değil.
- Galeri ilan uygulaması değil.
- AI wrapper gibi görünmeyecek.
- Aşırı neon, 3D, emoji, mavi-mor gradyan, generic SaaS kartları yok.
- Dijital kokpit / gösterge paneli estetiğinde: karanlık kabin, hassas enstrümanlar, tek enerji vurgusu. Yumuşak lüks değil — teknik, enerjik ve prestijli bir dijital dosya hissi verecek.

Ana his:

> Aracının dijital pasaportu — kokpit hassasiyetinde.

## 2. Tasarım felsefesi

**Cockpit Black.** Gerçek siyah (AMOLED) tuval; tek aktif vurgu turkuaz, kritik semantik için rezerve racing kırmızı.

- **True-Black Canvas:** Saf siyah (#000000) zemin; derinlik renkle değil, ince tonal yüzey farkı ve 1px çerçevelerle kurulur.
- **Single Energy Accent:** Turkuaz (#00E5C7) tek aktif/enerji vurgusudur — CTA, aktif durum, canlı metrik. Başka dekoratif renk yok.
- **Reserved Red:** Racing kırmızı (#FF2D3C) yalnızca kritik/destructive semantikte kullanılır; dekoratif kullanımı yasaktır.
- **Terminal Precision:** Monospaced tipografi (JetBrains Mono) artık hero metriğe de uzanır — plaka, tutar, km ve büyük göstergeler terminal/odometre gibi okunur.
- **Subtle Depth:** 1px turkuaz border'lar ve iç highlight'lar, flat/modern profili bozmadan fiziksel katman hissi yaratır.

Ana kural:

> AI varsayılanını öldür, native iOS güvenini koru, aracın dijital pasaportu kimliğini ekle.

## 3. Yasaklı "AI-slop" işaretleri

Aşağıdakiler üretimde kullanılmayacak:

- Mavi-mor generic gradient.
- Her yerde aynı yuvarlak köşeli kart.
- Dekoratif ama işlevsiz dashboard card mosaic.
- Inter / Roboto / Arial gibi web/SaaS default hissi veren font dayatması.
- Rastgele emoji ikonları.
- Rastgele 3D araba illüstrasyonu.
- Aşırı gölge (shadow kullanılmaz; border-based elevasyon).
- Her ekranın aynı kart yığını gibi görünmesi.
- Boş durum, hata durumu ve loading durumu olmayan ekranlar.
- "Something went wrong" gibi güven kıran hata mesajları.
- Renklerin anlam taşımadan kullanılması.
- Sadece güzel görünen ama gerçek veriyle dağılan layout.
- Light/dark mode adaptive renk karmaşası.
- Tam daire progress ring (Apple Fitness/Nike Activity Ring klonu) — bunun yerine yarım daire takometre-yayı kullanılır.
- Dolgu (filled) primary buton — bunun yerine tracked-uppercase bordered buton kullanılır.

## 4. Tema

**Dark-only.** Sistem görünümünden bağımsız, her zaman dark tema.

- UIUserInterfaceStyle = Dark (launch flash önlenir).
- `.preferredColorScheme(.dark)` root WindowGroup'ta.
- Asset catalog'da light varyant yok. Tüm renkler code-based hex.

## 5. Renk sistemi

Renkler semantik token üzerinden kullanılır. Ham hex doğrudan view içinde kullanılmaz.
Kaynak: `DesignSystem/AppColors.swift` (code-based, asset catalog kullanılmaz).

### Ana palet

**Background / Surface:**
| Token | Hex | Kullanım |
|---|---|---|
| backgroundPrimary | #000000 | En derin arka plan — AMOLED siyah (surface-container-lowest) |
| backgroundSecondary | #0A0A0A | Ana arka plan / surface |
| surfacePrimary | #121214 | Kart yüzeyleri (surface-container-low) |
| surfaceSecondary | #1A1A1C | Hafif elevasyonlu yüzey (surface-container) |

**Text:**
| Token | Hex | Kullanım |
|---|---|---|
| textPrimary | #F5F5F7 | Soft white (saf beyaz değil, düşük glare) |
| textSecondary | #9A9AA0 | Nötr gri secondary text |
| textTertiary | #6E6E73 | Muted outline rengi |
| textOnAccent | #00251F | Turkuaz vurgu üstünde koyu teal metin |

**Accent (Turkuaz):**
| Token | Hex | Kullanım |
|---|---|---|
| accentPrimary | #00E5C7 | Turkuaz — birincil vurgu, CTA, aktif durum |
| accentSecondary | #33EDD4 | Açık turkuaz — ikincil vurgu, gradient |
| accentMuted | #00E5C7 @ 12% | Turkuaz tinted arka plan |

**Semantic:**
| Token | Hex | Kullanım |
|---|---|---|
| success | #3B8F5A | Yeşil — başarı/tamamlandı (siyah üzerinde ≥4.5:1) |
| warning | #D4A017 | Amber — yaklaşan tarih/uyarı |
| critical | #FF2D3C | Racing kırmızı — SADECE kritik/gecikmiş; dekoratif kullanım yasak |

**Functional:**
| Token | Hex | Kullanım |
|---|---|---|
| border | #2A2A2C | 1px nötr hairline kart çerçevesi — HUD/teknik şema |
| divider | #FFFFFF @ 5% | Subtitle divider |

### Renk kullanımı

- Primary (Turkuaz): Yalnızca CTA, aktif durum ve canlı metrikler için.
- Secondary (Açık Turkuaz): Gradient ve ikincil vurgular için.
- Neutral (Cockpit Black): UI'ın temeli; #000000 ana canvas, #121214 elevated surface.
- Functional: Success ve Warning koyu temaya entegre; Critical (racing kırmızı) yalnızca kritik semantikte, asla dekoratif değil.
- Border: Nötr hairline (#2A2A2C) — kart çerçeveleri turkuaz DEĞİLDİR; turkuaz yalnızca aktif/enerji vurgusudur.

## 6. Tipografi

SF Pro (UI metinleri) + JetBrains Mono (teknik/finansal veri). Dynamic Type desteklenir.

Kaynak: `DesignSystem/AppTypography.swift`

### SF Pro Display — Başlıklar
| Token | Font | Size | Weight |
|---|---|---|---|
| heroMetric | JetBrains Mono | 64px | Light (300) |
| screenTitle | SF Pro Display | 28px | Bold (700) |
| sectionTitle | SF Pro Display | 18px | Semibold (600) |

### SF Pro Text — Gövde
| Token | Font | Size | Weight |
|---|---|---|---|
| cardTitle | SF Pro Text | 16px | Semibold (600) |
| bodyMain | SF Pro Text | 16px | Regular (400) |
| bodySecondary | SF Pro Text | 14px | Regular (400) |
| labelCaps | SF Pro Text | 11px | Medium (500) |

### JetBrains Mono — Teknik Veri
| Token | Font | Size | Weight | Kullanım |
|---|---|---|---|---|
| plateDisplay | JetBrains Mono | 24px | Bold (700) | Plaka gösterimi |
| amountLg | JetBrains Mono | 32px | Light (300) | Büyük tutar |
| amountMd | JetBrains Mono | 20px | SemiBold (600) | Orta tutar/km |
| labelMono | JetBrains Mono | 11px | Regular (400) | Mono etiket |

### Kurallar

- Tüm tutar, plaka, km okumaları JetBrains Mono kullanır.
- Büyük display metrikler (Hero Numbers) Light weight ile elegance hissi verir.
- Body metin soft white (#F5F5F7) kullanır, saf beyaz değil.
- `.monospacedDigit()` yerine JetBrains Mono (doğal monospaced).
- Metinler kırpılmadan gerçek veriyle test edilecek.
- Dynamic Type otomatik desteklenir (sistem font'ları ile).

## 7. Spacing sistemi

8pt grid.

Kaynak: `DesignSystem/AppSpacing.swift`

Tokenlar:

- `xxs = 4`, `xs = 8`, `sm = 12`, `md = 16`, `lg = 24`, `xl = 32`, `xxl = 48`
- `gutter = 16`, `marginScreen = 16`

Kurallar:

- İlgili öğeler: 8-12pt
- Kart içi padding: 16-20pt
- Bölümler arası: 24-32pt
- Ana CTA çevresi: 24-48pt
- Ekran yatay margin: 16pt
- Liste satır yüksekliği: minimum 52pt
- Tap target: minimum 44pt

## 8. Radius sistemi

Kaynak: `DesignSystem/AppRadius.swift`

| Token | Değer | Kullanım |
|---|---|---|
| small | 4 | İnce kenar detayı |
| medium | 6 | Kontroller (buton, input) |
| large | 6 | Kart container'ları |
| xlarge | 10 | Hero/medya kartları |
| capsule | 9999 | Status chip/pill |

Kullanım:

- Container'lar (kartlar): 6px — keskin, teknik, HUD/kokpit hissi (yuvarlak köşe klişesinden kaçış).
- Kontroller (buton/input): 6px — keskin, fonksiyonel.
- Status element'ler (chip/pill): tam yuvarlak (9999).
- Hero medya: "full-bleed" header'da sadece üst köşeler 10px.

## 9. Elevasyon sistemi (Border-based)

**Gölge kullanılmaz.** Derinlik 1px nötr hairline border (#2A2A2C) ile sağlanır — soft shadow "koyu mod SaaS dashboard" klişesidir.

Kaynak: `DesignSystem/AppShadows.swift`

| Modifier | Kullanım |
|---|---|
| `.subtleShadow()` | Hafif elevasyon — ince hairline çerçeve (6px radius) |
| `.cardShadow()` | Kart elevasyonu — hairline çerçeve (6px radius) |
| `.elevatedShadow()` | Yüksek elevasyon — hairline çerçeve + üst kenar 1px white @ 8% highlight |

- Hero/elevated kartlarda üst kenarda 1px beyaz highlight (0 1px 0 rgba(255,255,255,0.08)) fiziksel kalınlık hissi verir — saf siyah zeminde 0.05 yeterince okunmadığı için 0.08.
- Tab bar glassmorphism: background blur + surface color, 1px hairline üst border; aktif ikon turkuaz.

## 10. İkonografi

SF Symbols ana ikon seti olacak.

Kurallar:

- Her kategori için net SF Symbol seçilecek.
- Emoji kullanılmayacak.
- Aynı sembol stili korunacak.
- Filled/hierarchical/palette kullanımı tutarlı olacak.
- Silme için `trash`.
- Belge için `doc.text`.
- Sigorta/kasko için `shield`.
- Muayene için `checkmark.seal`.
- Bakım için `wrench.and.screwdriver`.
- Yakıt için `fuelpump`.
- Satış dosyası için `doc.richtext` / `qrcode` / `square.and.arrow.up`.

## 11. Motion ve haptik

Motion premium his vermeli, oyuncak gibi olmamalı.

Kullanılacak yerler:

- Araç ekleme tamamlandı.
- Bakım kaydı eklendi.
- Hatırlatıcı tamamlandı.
- Satış dosyası oluşturuldu.
- Paywall'dan Pro açıldı.
- Dosya tamlık skoru yükseldi.

Kurallar:

- Tap-pop küçük ve hızlı.
- Spring yalnızca anlamlı geçişte.
- `accessibilityReduceMotion` kontrol edilecek.
- Haptik başarı/uyarı/kritik ayrımına göre kullanılacak.
- Her butona haptik koyma; önemli state değişimlerine koy.

## 12. Component sistemi

Merkezi komponentler (`DesignSystem/Components/`):

- `VehicleCard` — Ana garaj kartı (plaka, bilgi, durum)
- `VehicleHeroHeader` — Araç detay hero (fotoğraf, plaka, info badge'ler)
- `QuickActionTile` / `QuickActionRail` — Hızlı işlem butonları
- `SectionHeaderMetricCard` — Bölüm başlığı + metrik kartı
- `OwnershipInsightCard` / `PremiumMetricHero` — Rapor metrikleri
- `TachometerGauge` — İmza grafik: tik işaretli + ibreli yarım daire takometre gauge (skorlar için)
- `ReticleCorners` — İmza motif: köşe ayraç/nişangah çerçevesi (araç fotoğrafı, tarama alanları)
- `DossierCompletenessCard` — Dosya tamlık skoru (TachometerGauge kullanır)
- `DosyaniTamamlaChecklist` — Onboarding checklist
- `EmptyStateView` / `ErrorStateView` — Boş/hata durumu
- `ArviaGuideCard` — Kontekst rehber kartı
- `ContextualTipBanner` — İpucu banner'ı
- `BrandIntroView` — İlk açılış marka animasyonu
- `PrimaryButtonStyle` / `SecondaryButtonStyle` / `DestructiveButtonStyle`

Kart yalnızca gerçekten anlamlıysa kullanılacak. Her veri parçası kart olmak zorunda değil.

## 13. Form elemanları

- **Input:** Surface'ten daha koyu (#000000), 1px border (idle nötr hairline #2A2A2C, focus turkuaz %100). 52pt yükseklik.
- **Primary Button:** Dolgu yok — 1.5pt turkuaz (#00E5C7) çerçeve, surface zemin, tracked-uppercase turkuaz label. 6px radius, minimum 44pt. (Filled buton yasak — bkz. bölüm 3.)
- **Secondary Button:** 1px turkuaz border (%60 opacity), transparan arka plan, turkuaz text.
- **Destructive Button:** Racing kırmızı fill (#FF2D3C), `textOnCritical` koyu metin (#2B0A0C, ≥4.5:1). 6px radius.

## 14. Navigasyon

- **Floating Tab Bar:** 16px yatay margin, 8px alt margin. 1px nötr hairline üst border. Aktif ikon turkuaz renginde.
- **Tab Bar Background:** Glassmorphism — `systemUltraThinMaterialDark` blur + surface color.
- **Segmented Control:** Normal #9A9AA0, Selected #00E5C7.

## 15. Empty state kuralları

Boş durum çıkmaz sokak olmayacak. Her boş durumda:

1. Ne olmadığı açıkça söylenecek.
2. Neden önemli olduğu anlatılacak.
3. Tek net CTA verilecek.

## 16. Hata mesajları

Hata mesajı formatı:

1. Ne oldu?
2. Kullanıcı ne yapabilir?
3. Veri kaybı var mı?

## 17. Signature interaction

### Araç Yaşam Çizgisi

Araç detay ekranında aracın kronolojik timeline'ı premium bir "yaşam çizgisi" olarak gösterilir.

- Satın alma, ilk kayıt, bakımlar, parça değişimleri, sigorta/kasko, muayene, ekspertiz, satış dosyası.

Bu timeline, uygulamanın ruhunu taşır. Sıradan gider listesi değil, aracın hafızasıdır.

## 18. Erişilebilirlik

- Dynamic Type zorunlu.
- VoiceOver label zorunlu.
- Icon-only button yoksa label olacak.
- Kontrast normal metinde en az 4.5:1.
- Büyük metinde 3:1.
- Tap target minimum 44pt.
- Reduce Motion desteklenecek.

## 19. Paywall tasarım ilkeleri

Paywall güven kırmayacak.

Zorunlu:

- Restore purchases linki.
- Cancel anytime / istediğin zaman iptal et mesajı.
- Fiyat netliği.
- Abonelik süresi netliği.
- Dark pattern yok.
- CTA gizli/aldatıcı olmayacak.
- Free limit neden var açık anlatılacak.

## 20. Design review skoru

Her major ekran şu 5 başlıkta en az 7/10 almalı:

1. Felsefe tutarlılığı
2. Görsel hiyerarşi
3. Detay işçiliği
4. İşlevsellik
5. Özgünlük

Ek kontroller:

- Tek tema (dark-only) testi
- Kontrast testi
- Gerçek veri testi
- Uzun metin testi
- Boş/hata/loading testi
- JetBrains Mono render testi
