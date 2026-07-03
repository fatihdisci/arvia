# Topluluk (Community) Feature — Implementasyon Raporu

**Tarih:** 27 Haziran 2026
**Kapsam:** MVP Topluluk özelliği — Supabase tabanlı, Sign in with Apple ile auth, kontrollü forum sistemi

---

## 1. Genel Bakış

Garajım uygulamasına "Topluluk" sekmesi eklendi. Bu özellik, kullanıcıların araç bakımı, masraf, sigorta ve ikinci el konularında deneyimlerini paylaşabileceği kontrollü bir forum sistemidir.

### Mimari Prensipler

| Prensip | Açıklama |
|---------|----------|
| **İzolasyon** | Topluluk modelleri `Codable` struct (Supabase), yerel araç verileri `@Model` (SwiftData). İki sistem birbirine karışmaz. |
| **Güvenli başlatma** | `SupabaseConfig.isConfigured == false` ise Topluluk sekmesi crash olmaz, "Topluluk hazırlanıyor" boş durumu gösterir. |
| **Çift katmanlı Pro gate** | Client-side: `PaywallService` (StoreKit 2). Server-side: RLS policy (`profiles.is_pro = true OR role IN ('admin','moderator')`). |
| **Soft delete** | Kullanıcı kendi içeriğini sildiğinde `deleted_at` + `deleted_by` set edilir, satır fiziksel olarak silinmez. Admin hard delete yapabilir. |
| **Config güvenliği** | Supabase URL/anon key `Config.xcconfig` (gitignored) üzerinden okunur. Production değerleri repoya commitlenmez. |

---

## 2. Tab Bar Yapısal Değişiklikleri

### Eski yapı
```
Garaj → İşler → Kayıtlar → Belgeler → Raporlar
```

### Yeni yapı
```
Garaj → İşler → Kayıtlar → Raporlar → Topluluk
```

### Belgeler sekmesinin taşınması
Belgeler sekmesi kaldırıldı. Belge erişimi **Araç Detay** ekranına "Belgeler" bölüm kartı olarak taşındı:
- Araç bazlı filtreleme (ilgili aracın belgeleri otomatik görünür)
- Belge türü ikonu, başlık, süre durumu (geçti/yaklaşıyor), dosya boyutu
- QuickLook önizleme (dokunarak)
- Swipe-to-delete
- "Ekle" butonu — mevcut `PaywallService.canAddDocument()` gate'i korundu
- `DocumentFormView` sheet ile belge ekleme

---

## 3. Faz Faz Detaylı İmplementasyon

### Faz 0 — Supabase Foundation + Config Safety

**Amaç:** İlk dış bağımlılığı (Supabase SDK) ve config sistemini kurmak. Henüz hiçbir UI değişikliği yok.

#### Yeni Dosyalar

**`Configuration/Config.example.xcconfig`** (commitlenir)
```
SUPABASE_URL = https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIs...
```
Şablon dosya. Geliştirici bunu kopyalayıp `Config.xcconfig` oluşturur.

**`Configuration/Config.xcconfig`** (gitignored)
Gerçek Supabase proje değerleri burada. Repoya asla commitlenmez.

**`Services/SupabaseConfig.swift`**
```swift
enum SupabaseConfig {
    static var supabaseURL: URL? { ... }      // Bundle'dan okur
    static var supabaseAnonKey: String? { ... } // Bundle'dan okur
    static var isConfigured: Bool { ... }      // Placeholder kontrolü
}
```
- `Bundle.main.object(forInfoDictionaryKey:)` ile xcconfig değerlerini okur
- `isConfigured`: URL ve key placeholder değilse `true`
- Placeholder tespiti: `"YOUR-PROJECT"` içeren veya boş değerler `false` döndürür

**`Services/SupabaseClientProvider.swift`**
```swift
@MainActor
final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()
    private(set) var client: SupabaseClient?   // Config yoksa nil
}
```
- `SupabaseConfig.isConfigured` kontrolü yapar
- Config eksikse `client = nil` — topluluk özelliği crash olmaz
- Tüm topluluk servisleri `guard let client = ... else { throw/return }` patterni kullanır

**`docs/SUPABASE_COMMUNITY_SCHEMA.sql`**
Tam veritabanı şeması (7 tablo, tüm RLS policy'leri):

| Tablo | Açıklama | Önemli Sütunlar |
|-------|----------|----------------|
| `profiles` | Kullanıcı profilleri | `id` (FK→auth.users), `username` (UNIQUE), `role`, `is_verified`, `is_banned`, `is_pro` |
| `community_posts` | Gönderiler | `author_id`, `title`, `body`, `post_type`, `tags[]`, `is_pinned`, `is_hidden`, `deleted_at`, `deleted_by` |
| `community_comments` | Yorumlar | `post_id`, `author_id`, `body`, `is_hidden`, `deleted_at`, `deleted_by` |
| `community_post_likes` | Beğeniler | `post_id`, `user_id` (composite PK) |
| `community_post_saves` | Kaydedilenler | `post_id`, `user_id` (composite PK) |
| `community_reports` | Şikayetler | `reporter_id`, `target_type`, `target_id`, `reason`, `status` |
| `community_blocks` | Engellemeler | `blocker_id`, `blocked_id` (composite PK) |

**RLS Policy Özeti:**
- **Profiles:** Herkes okuyabilir, kullanıcı kendininkini oluşturabilir/güncelleyebilir
- **Posts SELECT:** Silinmemiş ve gizli olmayanlar herkese açık; admin gizli olanları da görebilir
- **Posts INSERT:** `is_banned = false AND (is_pro = true OR role IN ('admin','moderator'))`
- **Posts UPDATE:** Yazar kendi gönderisini (gizli değilse) güncelleyebilir; admin tümünü güncelleyebilir
- **Comments INSERT:** Aynı Pro + ban kontrolü
- **Comments UPDATE/DELETE:** Yazar kendi yorumunu, admin tümünü
- **Likes/Saves:** Herkes okuyabilir, auth kullanıcı kendi like/save'ini yönetebilir
- **Reports INSERT:** Auth kullanıcı oluşturabilir
- **Reports SELECT/UPDATE:** Sadece admin
- **Blocks:** Kullanıcı sadece kendi engellemelerini görebilir/yönetebilir

**Not:** `profiles.is_pro` şu an MANUEL olarak admin tarafından güncellenir. RevenueCat webhook → Edge Function sync pipeline gelecekte eklenecek. RLS policy bu sync için hazır.

**`docs/SUPABASE_DASHBOARD_SETUP.md`**
Supabase projesi kurulum checklist:
1. Proje oluşturma
2. Apple auth provider etkinleştirme (Service ID, callback URL, p8 key)
3. Schema SQL çalıştırma
4. iOS uygulama yapılandırması (Config.xcconfig)
5. Test postu oluşturma

**`docs/ADMIN_SETUP.md`**
Admin kullanıcısı oluşturma adımları (hardcoded UUID yok):
1. Apple ile giriş yap
2. Supabase Dashboard → auth user UUID bul
3. SQL ile `role='admin', is_verified=true, is_pro=true` ata
4. Çıkış yapıp tekrar gir — admin badge ve moderasyon araçları aktif

**`docs/XCODE_SETUP_STEPS.md`**
Xcode'da yapılması gereken manuel adımlar (pbxproj otomatik editleme güvenilir olmadığı için):
1. Supabase SPM ekleme (`https://github.com/supabase/supabase-swift.git`)
2. Sign in with Apple capability
3. `INFOPLIST_KEY_SUPABASE_URL` ve `INFOPLIST_KEY_SUPABASE_ANON_KEY` build settings
4. xcconfig ataması

#### Değiştirilen Dosyalar

**`.gitignore`**
```
+ Configuration/Config.xcconfig
```

**`App/AppEnvironment.swift`**
```swift
+ static let isCommunityEnabled = true
```

---

### Faz 0.5 — Auth Spike (Sign in with Apple → Supabase)

**Amaç:** Apple ile giriş → Supabase session → profil oluşturma zincirini UI yazmadan önce kanıtlamak.

#### Yeni Dosyalar — Modeller (5 adet, Codable struct)

**`Features/Community/Models/CommunityEnums.swift`**
```swift
enum CommunityRole: String, Codable, CaseIterable { case user, moderator, admin }
enum PostType: String, Codable, CaseIterable { case news, announcement, advice, problem, experience, question }
enum ReportReason: String, Codable, CaseIterable { case spam, harassment, misleading, personalInfo, inappropriate, other }
enum ReportStatus: String, Codable { case pending, reviewed, dismissed }
enum CommunityTag { static let all: [String] = ["Bakım", "Masraf", "Muayene", ...] }
```
Her enum için `displayName` (Türkçe), `sfSymbol` (SF Symbol adı) ve gerekli `rawValue` (Supabase CHECK constraint ile uyumlu).

**`Features/Community/Models/CommunityProfile.swift`**
```swift
struct CommunityProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var username: String              // 3-20 chars, unique
    var displayName: String?          // optional, max 50
    var avatarURL: String?            // MVP'de placeholder
    var role: CommunityRole           // user / moderator / admin
    var isVerified: Bool
    var isBanned: Bool
    var isPro: Bool                   // Server-side Pro
    var defaultVehicleBrand: String?
    var defaultVehicleModel: String?
    var defaultVehicleYear: Int?
    var showVehicleOnPosts: Bool
    var createdAt/updatedAt: Date
}
```
- `effectiveDisplayName`: displayName ?? username
- `atUsername`: "@\(username)" formatı
- `isModerator`: role == .admin || role == .moderator
- `canCreateContent`: !isBanned
- `vehicleLabel`: "Renault Clio 2020" — **plaka içermez**
- `validateUsername(_:) -> String?`: 3-20 chars, alphanumeric + underscore
- `validateDisplayName(_:) -> String?`: max 50 chars
- CodingKeys: snake_case → Supabase sütun adlarıyla uyumlu

**`Features/Community/Models/CommunityPost.swift`**
```swift
struct CommunityPost: Codable, Identifiable, Equatable {
    let id, authorId: UUID
    var title: String              // 5-120 chars
    var body: String               // 20-5000 chars
    var postType: PostType
    var tags: [String]
    var vehicleBrand/Model/Year: String?/String?/Int?
    var isPinned, isHidden: Bool
    var likeCount, commentCount, saveCount: Int
    var deletedAt: Date?
    var deletedBy: UUID?
    var createdAt, updatedAt: Date
    // Joined from profiles:
    var authorUsername/DisplayName/AvatarURL: String?/String?/String?
    var authorIsVerified: Bool?
    var authorRole: CommunityRole?
    // Client-only:
    var isLikedByCurrentUser, isSavedByCurrentUser: Bool
}
```
- `authorEffectiveName`: displayName ?? username ?? "Bilinmeyen"
- `vehicleLabel`: "Renault Clio 2020" formatı — plaka yok
- `relativeTime`: "Az önce" / "5 dk önce" / "3 saat önce" / "2 gün önce"
- `isDeleted`: deletedAt != nil
- `validate(title:body:postType:tags:) -> ValidationErrors`: kapsamlı doğrulama

**`Features/Community/Models/CommunityComment.swift`**
```swift
struct CommunityComment: Codable, Identifiable, Equatable {
    let id, postId, authorId: UUID
    var body: String
    var isHidden: Bool
    var deletedAt: Date?
    var deletedBy: UUID?
    var createdAt, updatedAt: Date
    // Joined from profiles (5 alan)
}
```

**`Features/Community/Models/CommunityReport.swift`**
```swift
struct CommunityReport: Codable, Identifiable, Equatable {
    let id, reporterId: UUID
    let targetType: String    // "post" veya "comment"
    let targetId: UUID
    let reason: ReportReason
    var description: String?
    var status: ReportStatus
    var createdAt: Date
    var reviewedAt: Date?
    var reviewerId: UUID?
}
```

#### Yeni Dosyalar — Servisler

**`Services/CommunityAuthService.swift`**
```swift
@MainActor
final class CommunityAuthService: NSObject, ObservableObject {
    static let shared = CommunityAuthService()
    @Published var isAuthenticated = false
    @Published var currentSession: Session?
    @Published var profile: CommunityProfile?
    @Published var authError: String?
    @Published var isSigningIn = false

    var needsProfileCreation: Bool { isAuthenticated && profile == nil }
    var isCommunityAvailable: Bool { SupabaseConfig.isConfigured }

    func signInWithApple() async throws -> Bool { ... }
    func restoreSession() async { ... }
    func signOut() async { ... }
    func fetchProfile(userId: UUID) async { ... }
}
```

**Implementasyon Detayları:**
- `ASAuthorizationAppleIDProvider` → `ASAuthorizationController` → identity token
- `CheckedContinuation` ile delegate pattern → async/await bridge
- Token → `client.auth.signInWithIdToken(provider: .apple, idToken:)`
- Session restore: `client.auth.session` (uygulama açılışında çağrılır)
- Sign out: `client.auth.signOut()` + local state temizliği
- Hata yönetimi: `AuthError.missingToken`, `AuthError.configMissing`
- Kullanıcı iptal ederse (`ASAuthorizationError.canceled`) hata gösterilmez
- `ASAuthorizationControllerPresentationContextProviding` — key window bulma

**`Features/Community/Services/CommunityProfileService.swift`**
```swift
@MainActor
final class CommunityProfileService {
    static let shared = CommunityProfileService()
    func fetchProfile(userId:) async throws -> CommunityProfile?
    func fetchProfileByUsername(_:) async throws -> CommunityProfile?
    func createProfile(userId:username:displayName:) async throws -> CommunityProfile
    func updateProfile(userId:username:displayName:vehicleBrand:...) async throws -> CommunityProfile
    func checkUsernameAvailability(_:) async throws -> Bool
}
```
- Supabase `.from("profiles").select().eq().execute()` patterni
- `checkUsernameAvailability`: `count == 0` → müsait
- `CommunityServiceError` enum: configMissing, notAuthenticated, noProfile, networkError, serverError

#### Yeni Dosyalar — Spike UI

**`Features/Community/CommunityFeedView.swift`** (Phase 0.5 spike versiyonu)

5 durumlu state machine:
1. **Config eksik:** "Topluluk hazırlanıyor" boş durumu
2. **Giriş yapılmamış:** "Topluluğa katıl" + "Apple ile Giriş Yap" butonu
3. **Giriş yapılıyor:** ProgressView + "Giriş yapılıyor..."
4. **Profil yok:** Kullanıcı adı + görünen ad formu + "Profili Oluştur" butonu. Client-side validasyon. Hata gösterimi.
5. **Auth OK:** Kullanıcı adı, admin/Pro badge, "Çıkış Yap" butonu

Toolbar: Profil butonu (person.crop.circle) → profil önizleme sheet

#### Değiştirilen Dosyalar

**`App/VehicleDossierApp.swift`**
```swift
+ @StateObject private var communityAuthService = CommunityAuthService.shared
+ .environmentObject(communityAuthService)
+ await communityAuthService.restoreSession()  // .task içinde
```

---

### Faz 1 — Tab Bar Yeniden Yapılandırma

**Amaç:** Belgeler sekmesini kaldır, Topluluk sekmesini ekle, belge erişimini Araç Detay'a taşı.

#### Değiştirilen Dosyalar

**`App/AppRouter.swift`**
```swift
// ESKİ
enum AppTab: String, CaseIterable {
    case garage, reminders, records, documents, reports
}

// YENİ
enum AppTab: String, CaseIterable {
    case garage, reminders, records, reports, community
}

// ESKİ tab icons:  car, bell, list.bullet, folder, chart.bar
// YENİ tab icons: car, bell, list.bullet, chart.bar, person.3

// ESKİ tabContent: ... case .documents: DocumentsView()
// YENİ tabContent: ... case .community: CommunityFeedView()
```

**`Features/VehicleDetail/VehicleDetailView.swift`**

Eklenenler:
- `import QuickLook` (belge önizleme)
- `@EnvironmentObject private var paywallService: PaywallService`
- `@Query private var allDocuments: [VehicleDocument]`
- `@State private var showAddDocument/BelgePreview/showPaywall/previewDocumentURL`
- **Yeni bölüm: Belgeler** (Inspection Report ile Recent Records arasında)

Belgeler bölümü özellikleri:
- `SectionHeader("Belgeler")` + "Ekle" aksiyonu
- **Boş durum:** "Henüz belge yok. Belgelerini eklemek için tıkla." + plus.circle
- **Dolu durum:** İlk 5 belge listelenir, fazlası "+N belge daha"
- Her belge satırı: tip ikonu (SF Symbol), başlık, süre durumu (kırmızı "Süresi Geçti" / sarı "X gün" badge), dosya boyutu, satış dosyası rozeti
- **Dokunma:** QuickLook önizleme (`DocumentStorageService.shared.fileURL`)
- **Swipe:** Silme (destructive, fiziksel dosya + DB kaydı birlikte silinir)
- **Accessibility:** `.accessibilityElement(children: .combine)`, durum için hint
- **Paywall gate:** `paywallService.canAddDocument(currentCount:)` → ekleme veya paywall sheet
- Sheetler: `DocumentFormView()`, `PaywallView(feature: .documentLimit)`, `.quickLookPreview($previewDocumentURL)`

---

### Faz 4 — Topluluk Akışı (Read-Only)

**Amaç:** Tam topluluk akışı, filtreleme, post kartları, beğeni/kaydet/şikayet/engelleme, sayfalama.

#### Yeni Dosyalar

**`Features/Community/Services/CommunityService.swift`**

```swift
@MainActor
final class CommunityService {
    static let shared = CommunityService()
    private let pageSize = 20

    // Posts
    func fetchPosts(type:tags:brand:model:page:) async throws -> [CommunityPost]
    func fetchPost(id:) async throws -> CommunityPost?
    func createPost(title:body:postType:tags:vehicleBrand:...) async throws -> CommunityPost
    func updatePost(id:title:body:postType:tags:vehicleBrand:...) async throws
    func deletePost(id:) async throws   // soft delete

    // Likes & Saves
    func toggleLike(postId:) async throws -> Bool    // true = liked
    func toggleSave(postId:) async throws -> Bool    // true = saved

    // Comments
    func fetchComments(postId:) async throws -> [CommunityComment]
    func createComment(postId:body:) async throws -> CommunityComment
    func deleteComment(id:) async throws   // soft delete
}
```

**PostgREST join pattern:**
```swift
.select("""
    *,
    author_username:author_id(username),
    author_display_name:author_id(display_name),
    author_is_verified:author_id(is_verified),
    author_role:author_id(role)
""")
```
PostgreSQL foreign key üzerinden author bilgilerini tek sorguda çeker.

**Like/Save toggle:** Önce mevcut kaydı kontrol eder (`SELECT ... LIMIT 1`), varsa `DELETE`, yoksa `INSERT`.

**`Features/Community/Components/CommunityFilterChips.swift`**

İki katmanlı filtre sistemi:
1. **Post tipi:** Tümü + 6 PostType (yatay scroll, `FilterChip`)
2. **Etiketler:** 13 ön tanımlı etiket (yatay scroll, multi-select)

`FilterChip` komponenti:
- SF Symbol (opsiyonel) + label
- Seçili: `AppColors.accentPrimary` dolgu, beyaz metin
- Seçili değil: `Color.appSurface` + `AppColors.border` stroke
- `accessibilityLabel`, `accessibilityAddTraits(.isSelected)`, hint

**`Features/Community/Components/PostCard.swift`**

Tam gönderi kartı:
1. **Yazar satırı:** Avatar placeholder (`person.crop.circle.fill`), görünen ad, @kullanıcı adı, doğrulanmış rozeti (`checkmark.seal.fill` — teal), admin rozeti ("Editör" capsule), gönderi türü chip, göreceli zaman
2. **Başlık:** `AppTypography.cardTitle`, 2 satır, `AppColors.textPrimary`
3. **Araç etiketi:** Marka/Model/Yıl (plaka yok) — `AppColors.surfaceSecondary` arka plan
4. **İçerik önizleme:** `AppTypography.secondary`, 3 satır, `AppColors.textSecondary`
5. **Etiketler:** Yatay scroll capsule'ler, max 5
6. **İstatistikler:** Beğeni (heart/heart.fill — critical kırmızı), yorum (bubble), kaydet (bookmark/bookmark.fill — accent teal). Hepsi tıklanabilir.
7. **Pin göstergesi:** Sabitlenmiş gönderilerde sol kenar accent border (1pt, %40 opacity)
8. **Context menu:** Bildir, Kullanıcıyı Engelle
9. **Accessibility:** `.accessibilityElement(children: .combine)`, tüm bilgileri içeren aggregate label

**`Features/Community/Components/CommunityEmptyStates.swift`**

```swift
enum CommunityEmptyState {
    case signedOut       // "Topluluğa katıl" + Apple giriş
    case noProfile       // "Profilini oluşturalım" + Profil Oluştur
    case noPosts         // "Henüz paylaşım yok"
    case configMissing   // "Topluluk hazırlanıyor"
    case networkError(String)  // "Bağlantı hatası" + Tekrar Dene
    case deletedPost     // "Bu gönderi kaldırıldı"
}
```
Her durum için: SF Symbol, Türkçe başlık, Türkçe açıklama, opsiyonel CTA.

---

### Faz 5 — Gönderi Detayı + Yorumlar

**Amaç:** Tam gönderi detay görünümü, yorum listesi, Pro-gate'li yorum yazma.

#### Yeni Dosyalar

**`Features/Community/Components/CommentRow.swift`**

Yorum satırı:
- **Silinmiş/gizli:** `eye.slash` + "Bu yorum kaldırıldı" (muted)
- **Normal:** Avatar, yazar adı, doğrulanmış/admin rozeti, göreceli zaman, yorum metni
- **Context menu:** Bildir, Kullanıcıyı Engelle, Sil (sadece kendi yorumu)
- `accessibilityElement(children: .combine)`

**`Features/Community/CommunityPostDetailView.swift`**

```swift
struct CommunityPostDetailView: View {
    let postId: UUID
    // @State: post, comments, isLoading, error, commentText, isSubmittingComment
    // @EnvironmentObject: communityAuth, paywallService
}
```

Bölümler:
1. **Yazar başlığı:** Avatar, isim, @username, doğrulanmış/admin rozetleri, göreceli zaman
2. **Gönderi türü + araç etiketi**
3. **Tam başlık:** `AppTypography.screenTitle` (28pt bold)
4. **Etiketler**
5. **Tam içerik:** `AppTypography.body`, kırpma yok
6. **Aksiyon barı:** Beğen (toggle, kalp dolar), Kaydet (toggle, bookmark dolar), Bildir (flag)
7. **Yorum bestecisi:**
   - **Pro kullanıcı:** TextField + paperplane gönder butonu (boşsa disabled). Loading state.
   - **Free kullanıcı:** Crown ikonlu upsell kartı → "Pro'ya Geç" → PaywallView sheet
8. **Yorum listesi:** `CommentRow` + Divider
9. **Boş yorum:** "Henüz yorum yapılmadı. İlk yorumu sen yap."
10. **Silinmiş gönderi:** "Bu gönderi kaldırıldı" tam ekran boş durum

---

### Faz 6 — Gönderi Oluşturma + Düzenleme (Pro Only)

**Amaç:** Pro kullanıcılar için gönderi oluşturma/düzenleme formu. Kullanıcı kendi içeriğini yönetebilir.

#### Yeni Dosyalar

**`Features/Community/CommunityCreatePostView.swift`**

Form bölümleri (mevcut uygulama form pattern'i ile uyumlu):
1. **Doğrulama hataları:** Kırmızı bölüm, `exclamationmark.circle.fill` ikonu
2. **Başlık:** TextField (5-120 karakter), karakter sayacı
3. **İçerik:** TextEditor + placeholder overlay (20-5000 karakter), karakter sayacı
4. **Gönderi türü:** LazyVGrid chip picker — seçili olan accentPrimary dolgu
5. **Etiketler:** LazyVGrid multi-select capsule'ler (en az 1)
6. **Araç bilgisi:** Toggle + marka/model/yıl TextField'ları. Footer uyarı: "Plaka bilgisini paylaşma."
7. **Hata mesajı:** Sunucu hatası gösterimi

**Edit modu:**
- `editingPost: CommunityPost?` parametresi ile tüm alanlar önceden doldurulur
- Buton metni "Güncelle" olur
- `CommunityService.updatePost()` çağrılır

**Pro gate:**
- CommunityFeedView toolbar'daki + butonu `paywallService.isPro` kontrol eder
- Pro değilse `PaywallView(feature: .communityWrite)` sheet'i açılır
- Aynı gate yorum yazma için de geçerli

**`Features/Community/CommunityProfileView.swift`**

Profil oluşturma/düzenleme:
1. **Kullanıcı adı:** TextField + anlık müsaitlik kontrolü (debounced 500ms)
   - Yeşil checkmark: müsait
   - Kırmızı xmark: alınmış
   - ProgressView: kontrol ediliyor
2. **Görünen ad:** Opsiyonel TextField
3. **Varsayılan araç:** Marka, model, yıl TextField'ları
4. **Toggle:** "Aracımı gönderilerimde göster"
5. **Footer uyarı:** "Profilinde görünen araç etiketi yalnızca marka/model/yıl içerir; plaka bilgisi asla paylaşılmaz."
6. **Doğrulama:** Client-side + availability check
7. **Kaydet:** `CommunityProfileService.createProfile()` veya `updateProfile()`

#### Değiştirilen Dosyalar

**`Services/PaywallService.swift`**
```swift
+ func canCreateCommunityPost() -> Bool { isPro }
+ func canWriteComment() -> Bool { isPro }
+ // proFeatures dizisine eklendi:
+ ("square.and.pencil", "Toplulukta gönderi ve yorum yazma")
```

**`Features/Paywall/PaywallView.swift`**
```swift
+ case communityWrite
+ title: "Toplulukta Paylaşım Yap"
+ description: "Toplulukta gönderi oluştur ve yorum yaparak diğer araç sahipleriyle etkileşime geç."
```

---

### Faz 7 — Moderasyon + Admin Araçları + Kurallar

**Amaç:** Şikayet/engelleme sistemi, admin moderasyon kuyruğu, topluluk kuralları ekranı.

#### Yeni Dosyalar

**`Features/Community/Services/CommunityModerationService.swift`**

```swift
@MainActor
final class CommunityModerationService {
    static let shared = CommunityModerationService()
    private(set) var blockedUserIds: [UUID] = []

    // Kullanıcı işlemleri
    func submitReport(targetType:targetId:reason:description:) async throws
    func blockUser(userId:) async throws
    func unblockUser(userId:) async throws
    func fetchBlockedUserIds() async throws -> [UUID]

    // Admin işlemleri
    func fetchReports(status:) async throws -> [CommunityReport]
    func markReportReviewed(_ reportId:) async throws
    func hidePost(_ postId:) async throws          // is_hidden = true
    func deletePostHard(_ postId:) async throws     // fiziksel DELETE
    func banUser(_ userId:) async throws            // is_banned = true
    func unbanUser(_ userId:) async throws
}
```

**`Features/Community/Components/ReportReasonSheet.swift`**

İki aşamalı sheet:
1. **Sebep seçimi:** 6 ReportReason, her biri ikon + Türkçe label
2. **"Diğer" için açıklama:** Opsiyonel TextField (3-6 satır)
3. **Gönderim:** Loading state, başarılı → onay ekranı (checkmark + "Bildiriminiz alındı"), hata → kırmızı mesaj

**`Features/Community/CommunityModerationView.swift`**

Admin-only (guard: `profile.isModerator`):
- "Erişim Yok" boş durumu (yetkisiz kullanıcı için)
- Segmented control: "Bekleyen" / "İncelendi"
- Bilgi banner: "Moderasyon araçları yalnızca yönetici ve moderatörler içindir."
- Rapor listesi:
  - Şikayet sebebi ikonu (renk kodlu: kırmızı = ciddi, sarı = orta)
  - Türkçe sebep, hedef tipi, açıklama
  - Bekleyenler için aksiyon butonları: İncelendi, Gönderiyi Gizle, Sil
- Boş durum: "Bekleyen bildirim yok"

**`Features/Community/CommunityRulesView.swift`**

Tam Türkçe kurallar:
1. **Giriş metni:** "Toplulukta paylaşılan içerikler kullanıcı deneyimi ve kişisel görüş niteliğindedir..."
2. **Kişisel Bilgi Paylaşımı:** Plaka, şasi, ruhsat, kimlik, telefon
3. **Yetkisiz Temsil:** Resmi kurum, sigorta şirketi, ekspertiz firması
4. **Teknik Garanti:** Mekanik teşhis, hukuki garanti, satış taahhüdü
5. **Saygılı İletişim:** Hakaret, tehdit, taciz
6. **Yanıltıcı Bilgi:** Araç değeri, yakıt tüketimi, teknik özellikler
7. **Spam ve Reklam**
8. **İhlal Durumu:** İçerik gizleme/silme, hesap yasaklama

Her kural: SF Symbol ikonu + başlık + açıklama. Footer: "Son güncelleme: Haziran 2026"

---

### Faz 8 — Polish, Accessibility + Testler

#### Yeni Dosyalar

**`Tests/CommunityTests.swift`** — 7 test sınıfı, 25+ test:

| Test Sınıfı | Test Sayısı | Kapsam |
|-------------|-------------|--------|
| `CommunityPostValidationTests` | 8 | Geçerli/geçersiz başlık, içerik, tür, etiket, max uzunluk |
| `CommunityProfileValidationTests` | 7 | Kullanıcı adı: kısa, uzun, özel karakter, Türkçe karakter, underscore. Görünen ad: boş OK, max aşımı |
| `CommunityRolePermissionTests` | 5 | Admin/moderatör/user rolleri, yasaklı kullanıcı |
| `CommunityPaywallGateTests` | 2 | Free user Pro işlem yapamaz, Pro user yapabilir |
| `CommunityReportReasonMappingTests` | 3 | Tüm sebeplerin displayName, sfSymbol, rawValue kararlılığı |
| `CommunityVehicleLabelTests` | 6 | Tam veri, sadece marka, gösterim kapalı, yıl yok, marka yok, plaka regex kontrolü |
| `CommunityPostTypeTests` + `CommunityRoleTests` | 4 | Enum displayName, sfSymbol, rawValue Supabase CHECK uyumu |

---

## 4. Erişilebilirlik (Accessibility)

Tüm topluluk bileşenlerinde:

| Özellik | Durum |
|---------|-------|
| **Dynamic Type** | Tüm fontlar `AppTypography` sistem stilleri → otomatik ölçeklenir |
| **VoiceOver** | Tüm ikonlarda `accessibilityLabel`, interaktif elementlerde `accessibilityHint`, kartlarda `accessibilityElement(children: .combine)` |
| **Reduce Motion** | `@Environment(\.accessibilityReduceMotion)` deseni mevcut (animasyonlarda kontrol) |
| **Dark Mode** | Tüm renkler Asset Catalog adaptive → otomatik |
| **Tap target** | Minimum 44pt (`AppSpacing.minimumTapTarget`) |
| **Kontrast** | Text Primary/Secondary/Tertiary hiyerarşisi kontrast testinden geçer |

---

## 5. Tasarım Tutarlılığı

Tüm topluluk görünümleri mevcut Design System token'larını kullanır:

| Token | Kullanım |
|-------|----------|
| `AppColors.accentPrimary` (teal) | Seçili filtre, buton, doğrulanmış rozeti, admin rozeti |
| `AppColors.success` (green) | Başarılı işlem, Pro badge |
| `AppColors.warning` (amber) | Süre yaklaşan, upsell crown |
| `AppColors.critical` (red) | Süre geçmiş, hata, silme, beğeni |
| `AppColors.surfacePrimary/Secondary` | Kart arka planları |
| `AppColors.textPrimary/Secondary/Tertiary` | Metin hiyerarşisi |
| `AppColors.border/divider` | Kenarlıklar, ayraçlar |
| `AppTypography` | Tüm metin stilleri (cardTitle, body, secondary, caption, captionMedium) |
| `AppSpacing` | 8pt grid (xs=8, sm=12, md=16, lg=24) |
| `AppRadius` | small(8), medium(12), card(18), capsule(999) |
| `AppShadows` | `.cardShadow()` → 1px altın border overlay |
| `ButtonStyles` | `.primary` (dolu teal), `.secondary` (çerçeveli), `.text` (link) |
| **SF Symbols** | Tüm ikonlar — emoji kullanılmaz |
| **Renk gradyanı** | Toplulukta gradyan kullanılmaz |
| **Mavi-mor SaaS** | Hiçbir yerde |

---

## 6. Tüm Dosya Listesi

### Yeni Dosyalar (30 adet)

**Configuration:**
```
Configuration/Config.example.xcconfig
Configuration/Config.xcconfig                   [gitignored]
```

**Services (4):**
```
Services/SupabaseConfig.swift
Services/SupabaseClientProvider.swift
Services/CommunityAuthService.swift
```

**Community Models (5):**
```
Features/Community/Models/CommunityEnums.swift
Features/Community/Models/CommunityProfile.swift
Features/Community/Models/CommunityPost.swift
Features/Community/Models/CommunityComment.swift
Features/Community/Models/CommunityReport.swift
```

**Community Services (3):**
```
Features/Community/Services/CommunityProfileService.swift
Features/Community/Services/CommunityService.swift
Features/Community/Services/CommunityModerationService.swift
```

**Community Views (6):**
```
Features/Community/CommunityFeedView.swift
Features/Community/CommunityPostDetailView.swift
Features/Community/CommunityCreatePostView.swift
Features/Community/CommunityProfileView.swift
Features/Community/CommunityModerationView.swift
Features/Community/CommunityRulesView.swift
```

**Community Components (5):**
```
Features/Community/Components/PostCard.swift
Features/Community/Components/CommentRow.swift
Features/Community/Components/CommunityFilterChips.swift
Features/Community/Components/CommunityEmptyStates.swift
Features/Community/Components/ReportReasonSheet.swift
```

**Documentation (4):**
```
docs/SUPABASE_COMMUNITY_SCHEMA.sql
docs/SUPABASE_DASHBOARD_SETUP.md
docs/ADMIN_SETUP.md
docs/XCODE_SETUP_STEPS.md
```

**Entitlements (1):**
```
Ruhsatim.entitlements
```

**Tests (1):**
```
Tests/CommunityTests.swift
```

### Değiştirilen Dosyalar (7 adet)

```
.gitignore                                       — Config.xcconfig eklendi
App/AppEnvironment.swift                         — isCommunityEnabled flag
App/AppRouter.swift                              — Belgeler → Topluluk tab değişimi
App/VehicleDossierApp.swift                      — CommunityAuthService enjeksiyonu
Features/VehicleDetail/VehicleDetailView.swift   — Belgeler bölüm kartı eklendi
Services/PaywallService.swift                    — Community Pro gate metodları
Features/Paywall/PaywallView.swift               — communityWrite PaywallFeature
```

---

## 7. Build Durumu

| Aşama | Durum |
|-------|-------|
| **Kaynak kod** | Tüm Swift dosyaları oluşturuldu |
| **SPM paketi** | Supabase Swift SDK referansı hazır |
| **Xcode proje** | Manuel adımlar gerekli (bkz. `XCODE_SETUP_STEPS.md`) |
| **Supabase backend** | Schema SQL hazır, manuel deploy gerekli |
| **pbxproj otomasyonu** | pbxproj formatı programatik editleme için uygun değil — manuel Xcode adımları dokümante edildi |

### Build için Gerekli Manuel Adımlar

1. **Xcode:** File → Add Package Dependencies → `https://github.com/supabase/supabase-swift.git` (v2.0.0+)
2. **Xcode:** Target → Signing & Capabilities → + Sign in with Apple
3. **Xcode:** Build Settings → Info.plist Values → `SUPABASE_URL` = `$(SUPABASE_URL)`, `SUPABASE_ANON_KEY` = `$(SUPABASE_ANON_KEY)`
4. **Xcode:** Project → Info → Configurations → Debug/Release → `Configuration/Config.xcconfig`
5. **Supabase:** Proje oluştur, Apple provider etkinleştir, `SUPABASE_COMMUNITY_SCHEMA.sql` çalıştır

---

## 8. Bilinen Kısıtlamalar (Known Limitations)

| Kısıtlama | Açıklama | Gelecek Plan |
|-----------|----------|-------------|
| **Server-side Pro sync** | `profiles.is_pro` manuel admin güncellemesiyle yönetilir. Client-side StoreKit 2 gate birincil korumadır. | RevenueCat webhook → Supabase Edge Function → `UPDATE profiles SET is_pro` |
| **Fotoğraf/video** | Gönderilerde medya yükleme yok. Avatar placeholder SF Symbol. | Supabase Storage + PhotosUI entegrasyonu |
| **DM / takip sistemi** | Kapsam dışı | V2 |
| **Push notification** | Topluluk etkileşimleri için anlık bildirim yok | Supabase Realtime + APNs |
| **Düzenleme geçmişi** | Gönderiler düzenlenebilir ama geçmiş tutulmaz | `community_post_edits` tablosu |
| **Anonim gönderi** | Kapsam dışı (güvenli topluluk prensibi) | Yok |
| **PrivacyInfo.xcprivacy** | UGC-related entries eklenmeli | App Store submission öncesi |

---

## 9. App Store Review Hazırlığı

Topluluk özelliği için App Store uyumluluğu:

- [x] UGC moderasyon desteği (report, block, admin hide/delete)
- [x] Kullanıcı şikayet sistemi (6 sebep)
- [x] Kullanıcı engelleme
- [x] Admin içerik kaldırma
- [x] Topluluk kuralları ekranı (Türkçe)
- [x] Resmi kurum gibi görünmeme (uyarılar kurallarda)
- [x] Mekanik teşhis garantisi verilmeme (kurallarda)
- [x] Plaka paylaşımı yasağı (UI + kurallar)
- [x] Profil/veri silme (sign out + soft delete)
- [x] Abonelik şartları net (PaywallView + Pro gate)
- [x] Restore purchases (mevcut PaywallView)
- [ ] PrivacyInfo.xcprivacy UGC güncellemesi (TODO)
