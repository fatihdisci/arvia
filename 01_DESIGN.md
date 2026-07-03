# DESIGN.md — Arvia Premium Tasarım Anayasası

## 1. Ürün karakteri

Bu uygulama premium, güvenilir, sakin ve profesyonel görünmelidir.
Tasarım konsepti: **"Aracın Dijital Pasaportu"** — aracının finansal ve teknik dosyası.

Uygulama dili:

- Araç takip defteri değil.
- Ucuz oto sanayi uygulaması değil.
- Galeri ilan uygulaması değil.
- AI wrapper gibi görünmeyecek.
- Aşırı neon, 3D, emoji, mavi-mor gradyan, generic SaaS kartları yok.
- Premium fintech + automotive estetiğinde, prestijli bir dijital dosya hissi verecek.

Ana his:

> Aracının dijital pasaportu.

## 2. Tasarım felsefesi

**Corporate Minimalism with Tactile Accents.** Dark luxury estetik; mat altın vurgulu deep navy zemin.

- **Minimalism:** Ağır negatif alan, kısıtlı renk paleti, finansal veriye odak.
- **High-Contrast Accents:** Derin lacivert-siyah tuval üzerinde mat altın vurgular değer ve önem belirtir.
- **Technical Precision:** Monospaced tipografi (JetBrains Mono) veri noktalarında hassasiyet ve mekanik güvenilirlik hissi verir.
- **Subtle Depth:** 1px altın border'lar ve iç highlight'lar, flat/modern profili bozmadan fiziksel katman hissi yaratır.

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
| backgroundPrimary | #0A0E1A | En derin arka plan (surface-container-lowest) |
| backgroundSecondary | #0F131F | Ana arka plan / surface |
| surfacePrimary | #171B28 | Kart yüzeyleri (surface-container-low) |
| surfaceSecondary | #1B1F2C | Hafif elevasyonlu yüzey (surface-container) |

**Text:**
| Token | Hex | Kullanım |
|---|---|---|
| textPrimary | #F5F0E8 | Cream-white (saf beyaz değil, düşük glare) |
| textSecondary | #8B95A8 | Gri-mavi secondary text |
| textTertiary | #999080 | Muted outline rengi |
| textOnAccent | #3F2E00 | Gold buton üstünde koyu metin |

**Accent (Mat Altın + Şampanya):**
| Token | Hex | Kullanım |
|---|---|---|
| accentPrimary | #E6C479 | Mat altın — birincil vurgu, CTA, aktif durum |
| accentSecondary | #D8C594 | Şampanya — ikincil vurgu, gradient |
| accentMuted | #E6C479 @ 12% | Gold tinted arka plan |

**Semantic:**
| Token | Hex | Kullanım |
|---|---|---|
| success | #2D5F3F | Koyu yeşil — başarı/tamamlandı |
| warning | #D4A017 | Amber/altın — yaklaşan tarih/uyarı |
| critical | #8B2C2C | Koyu kırmızı — gecikmiş/kritik |

**Functional:**
| Token | Hex | Kullanım |
|---|---|---|
| border | #C9A961 @ 15% | 1px altın kart çerçevesi |
| divider | #FFFFFF @ 5% | Subtitle divider |

### Renk kullanımı

- Primary (Mat Altın): Yalnızca CTA, aktif durum ve kritik finansal metrikler için.
- Secondary (Şampanya): Gradient ve ikincil vurgular için.
- Neutral (Deep Space): UI'ın temeli; #0A0E1A ana canvas, #171B28 elevated surface.
- Functional: Success, Warning, Critical koyu temaya entegre olacak şekilde desatüre.
- Border: Altın border %15 opacity ile "dağlanmış" (etched) görünüm.

## 6. Tipografi

SF Pro (UI metinleri) + JetBrains Mono (teknik/finansal veri). Dynamic Type desteklenir.

Kaynak: `DesignSystem/AppTypography.swift`

### SF Pro Display — Başlıklar
| Token | Font | Size | Weight |
|---|---|---|---|
| heroMetric | SF Pro Display | 64px | Light (300) |
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
- Body metin cream-white (#F5F0E8) kullanır, saf beyaz değil.
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
| medium | 8 | Kontroller (buton, input) |
| large | 16 | Kart container'ları |
| xlarge | 24 | Hero/medya kartları |
| capsule | 9999 | Status chip/pill |

Kullanım:

- Container'lar (kartlar): 16px — modern ve premium.
- Kontroller (buton/input): 8px — daha keskin, fonksiyonel.
- Status element'ler (chip/pill): tam yuvarlak (9999).
- Hero medya: "full-bleed" header'da sadece üst köşeler 16px.

## 9. Elevasyon sistemi (Border-based)

**Gölge kullanılmaz.** Derinlik 1px altın border (%15 opacity) ile sağlanır.

Kaynak: `DesignSystem/AppShadows.swift`

| Modifier | Kullanım |
|---|---|
| `.subtleShadow()` | Hafif elevasyon — ince altın çerçeve (4px radius) |
| `.cardShadow()` | Kart elevasyonu — altın çerçeve (16px radius) |
| `.elevatedShadow()` | Yüksek elevasyon — altın çerçeve + üst kenar 1px white @ 5% highlight |

- Hero/elevated kartlarda üst kenarda 1px beyaz highlight (0 1px 0 rgba(255,255,255,0.05)) fiziksel kalınlık hissi verir.
- Tab bar glassmorphism: background blur + surface color, 1px altın üst border.

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
- `DossierCompletenessCard` — Dosya tamlık skoru (progress ring)
- `DosyaniTamamlaChecklist` — Onboarding checklist
- `EmptyStateView` / `ErrorStateView` — Boş/hata durumu
- `ArviaGuideCard` — Kontekst rehber kartı
- `ContextualTipBanner` — İpucu banner'ı
- `BrandIntroView` — İlk açılış marka animasyonu
- `PrimaryButtonStyle` / `SecondaryButtonStyle` / `DestructiveButtonStyle`

Kart yalnızca gerçekten anlamlıysa kullanılacak. Her veri parçası kart olmak zorunda değil.

## 13. Form elemanları

- **Input:** Surface'ten daha koyu (#0A0E1A), 1px altın border (idle %15, focus %100). 52pt yükseklik.
- **Primary Button:** Solid altın fill (#C9A961), koyu text. 8px radius, minimum 44pt.
- **Secondary Button:** 1px altın border (%100 opacity), transparan arka plan, cream text.
- **Destructive Button:** Koyu kırmızı fill (#8B2C2C), cream text.

## 14. Navigasyon

- **Floating Tab Bar:** 16px yatay margin, 8px alt margin. 1px altın üst border. Aktif ikon altın renginde.
- **Tab Bar Background:** Glassmorphism — `systemUltraThinMaterialDark` blur + surface color.
- **Segmented Control:** Normal #8B95A8, Selected #E6C479.

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
