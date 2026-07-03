import SwiftUI

// MARK: - Community Empty States
// Topluluk özelliğinin tüm boş/hata durumları.

enum CommunityEmptyState: Equatable {
    case signedOut
    case noProfile
    case noPosts
    case configMissing
    case networkError(String)
    case deletedPost

    var icon: String {
        switch self {
        case .signedOut: return "person.crop.circle.badge.questionmark"
        case .noProfile: return "person.crop.circle.badge.plus"
        case .noPosts: return "bubble.left.and.bubble.right"
        case .configMissing: return "gearshape.2"
        case .networkError: return "wifi.slash"
        case .deletedPost: return "eye.slash"
        }
    }

    var title: String {
        switch self {
        case .signedOut: return "Topluluğa katıl"
        case .noProfile: return "Profilini oluşturalım"
        case .noPosts: return "Henüz paylaşım yok"
        case .configMissing: return "Topluluk hazırlanıyor"
        case .networkError: return "Bağlantı hatası"
        case .deletedPost: return "Bu gönderi kaldırıldı"
        }
    }

    var description: String {
        switch self {
        case .signedOut:
            return "Araç haberlerini, bakım tavsiyelerini ve kullanıcı deneyimlerini okumak için Apple ile giriş yap."
        case .noProfile:
            return "Toplulukta güvenli bir deneyim için kullanıcı adını belirle."
        case .noPosts:
            return "\(AppBrand.appName) topluluğunda haberler, tavsiyeler ve kullanıcı deneyimleri burada görünecek."
        case .configMissing:
            return "Topluluk özelliği şu anda yapılandırılıyor. Lütfen daha sonra tekrar kontrol et."
        case .networkError(let message):
            return message
        case .deletedPost:
            return "Bu gönderi yazar tarafından kaldırılmış veya bir moderatör tarafından gizlenmiş."
        }
    }

    var actionTitle: String? {
        switch self {
        case .signedOut: return "Apple ile Giriş Yap"
        case .noProfile: return "Profil Oluştur"
        case .noPosts: return nil
        case .configMissing: return nil
        case .networkError: return "Tekrar Dene"
        case .deletedPost: return nil
        }
    }
}

/// Topluluk boş durumları için yardımcı view.
struct CommunityEmptyStateView: View {
    let state: CommunityEmptyState
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            EmptyStateView(
                icon: state.icon,
                title: LocalizedStringKey(state.title),
                description: LocalizedStringKey(state.description),
                actionTitle: state.actionTitle.map { LocalizedStringKey($0) },
                action: action ?? {}
            )

            #if DEBUG
            if state == .configMissing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug: SupabaseConfig")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(SupabaseConfig.debugState())
                        .font(AppTypography.labelMono)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .fill(AppColors.surfaceSecondary)
                )
                .padding(.horizontal, AppSpacing.lg)
            }
            #endif

            Spacer()
        }
        .background(Color.appBackground)
    }
}
