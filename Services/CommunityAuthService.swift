import Foundation
import AuthenticationServices
import Supabase

// MARK: - Community Auth Service
// Sign in with Apple → Supabase auth entegrasyonu.
// ASAuthorizationControllerDelegate pattern'ini async/await ile bridge eder.

@MainActor
final class CommunityAuthService: NSObject, ObservableObject {
    static let shared = CommunityAuthService()

    // MARK: - Published State

    @Published var isAuthenticated = false
    @Published var currentSession: Session?
    @Published var profile: CommunityProfile?
    @Published var authError: String?
    @Published var isSigningIn = false

    // MARK: - Computed

    /// Giriş yapmış ama profili yok — profil oluşturma ekranı gösterilmeli.
    var needsProfileCreation: Bool {
        isAuthenticated && profile == nil
    }

    /// Topluluk özelliği kullanılabilir mi?
    var isCommunityAvailable: Bool {
        SupabaseConfig.isConfigured
    }

    // MARK: - Private

    private var client: SupabaseClient? {
        SupabaseClientProvider.shared.client
    }

    private var signInContinuation: CheckedContinuation<Bool, Error>?

    // MARK: - Sign In

    /// Apple ile giriş yap. Önce Apple ID doğrulaması, sonra Supabase auth.
    func signInWithApple() async throws -> Bool {
        guard client != nil else {
            authError = "Topluluk bağlantısı yapılandırılmamış."
            return false
        }

        isSigningIn = true
        authError = nil
        defer { isSigningIn = false }

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// SignInWithAppleButton completion handler — native HIG butonla kullanım için.
    /// `signInWithApple()` async versiyonu kendi ASAuthorizationController'ını oluşturur;
    /// bu metod native butonun completion handler'ından çağrılır.
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                authError = "Apple kimlik doğrulaması başarısız oldu."
                return
            }

            isSigningIn = true
            Task {
                guard let client = client else {
                    authError = "Topluluk bağlantısı yapılandırılmamış."
                    isSigningIn = false
                    return
                }

                do {
                    let session = try await client.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idTokenString)
                    )
                    currentSession = session
                    isAuthenticated = true
                    authError = nil

                    let userId = session.user.id
                    await fetchProfile(userId: userId)
                } catch {
                    authError = "Giriş yapılamadı. Lütfen tekrar dene."
                }

                isSigningIn = false
            }

        case .failure(let error):
            if let asAuthError = error as? ASAuthorizationError,
               asAuthError.code == .canceled {
                authError = nil
            } else {
                authError = "Apple ile giriş yapılamadı: \(error.localizedDescription)"
            }
        }
    }

    /// Uygulama açıldığında mevcut session'ı geri yükle.
    func restoreSession() async {
        guard let client = client else { return }

        do {
            let session = try await client.auth.session
            self.currentSession = session
            self.isAuthenticated = true

            // Profili de çek
            let userId = session.user.id
            await fetchProfile(userId: userId)
        } catch {
            // Session yok veya süresi dolmuş — normal, sessizce handle et.
            self.isAuthenticated = false
            self.currentSession = nil
            self.profile = nil
        }
    }

    /// Çıkış yap.
    func signOut() async {
        guard let client = client else { return }

        do {
            try await client.auth.signOut()
        } catch {
            // Çıkış hatası kritik değil.
        }

        isAuthenticated = false
        currentSession = nil
        profile = nil
    }

    /// Hesabı tamamen sil: auth.user, profil, postlar, yorumlar, tüm veriler.
    /// Apple ile tekrar girişte sıfırdan başlanır.
    /// Local SwiftData temizliği caller tarafından yapılır.
    func deleteAccount() async throws {
        guard let client = client else {
            throw CommunityServiceError.configMissing
        }

        guard currentSession?.user.id != nil else {
            throw CommunityServiceError.notAuthenticated
        }

        // RPC: auth.users + tüm community verilerini sil
        try await client.rpc("delete_community_account_full").execute()

        // RPC zaten auth.user'ı sildiği için oturum geçersiz.
        do {
            try await client.auth.signOut()
        } catch {
            // Sign out hatası kritik değil.
        }

        isAuthenticated = false
        currentSession = nil
        profile = nil
    }

    // MARK: - Profile

    /// Auth sonrası profil fetch et.
    func fetchProfile(userId: UUID) async {
        do {
            self.profile = try await CommunityProfileService.shared.fetchProfile(userId: userId)
        } catch {
            // Profil henüz oluşturulmamış olabilir.
            self.profile = nil
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension CommunityAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            signInContinuation?.resume(throwing: AuthError.missingToken)
            signInContinuation = nil
            return
        }

        Task {
            guard let client = client else {
                signInContinuation?.resume(throwing: AuthError.configMissing)
                signInContinuation = nil
                return
            }

            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idTokenString
                    )
                )

                self.currentSession = session
                self.isAuthenticated = true
                self.authError = nil

                // Profili çek
                let userId = session.user.id
                await fetchProfile(userId: userId)

                signInContinuation?.resume(returning: true)
            } catch {
                self.authError = "Giriş yapılamadı. Lütfen tekrar dene."
                signInContinuation?.resume(throwing: error)
            }

            signInContinuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // Kullanıcı iptal ettiyse hata gösterme.
        if let asAuthError = error as? ASAuthorizationError,
           asAuthError.code == .canceled {
            self.authError = nil
            signInContinuation?.resume(returning: false)
        } else {
            self.authError = "Apple ile giriş yapılamadı: \(error.localizedDescription)"
            signInContinuation?.resume(throwing: error)
        }
        signInContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension CommunityAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case missingToken
    case configMissing

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Apple kimlik doğrulama bilgisi alınamadı."
        case .configMissing:
            return "Topluluk bağlantısı yapılandırılmamış."
        }
    }
}
