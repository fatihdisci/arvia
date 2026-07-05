import SwiftUI

// MARK: - Onboarding View
// İlk kurulumda gösterilen 5 ekranlı rehber. Premium, sakin, Apple-native.
// Emoji yok, mavi-mor gradient yok, gereksiz illüstrasyon yok.
// Sekme yapısıyla uyumlu: Garaj · Asistan · Yapılacaklar · Kayıtlar (+ satış dosyası).

struct OnboardingView: View {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "car.fill",
            title: "Aracına iyi bak.",
            description: "Muayene, sigorta, bakım, masraf ve belgelerini tek yerde takip et.",
            color: AppColors.accentPrimary
        ),
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Sana özel akıllı asistan",
            description: "Kullanım profilini oluştur; yapay zekâ destekli kişisel bakım planı ve kilometre tahmini seni yönlendirsin.",
            color: AppColors.accentPrimary
        ),
        OnboardingPage(
            icon: "checklist",
            title: "Yapılacakları kaçırma",
            description: "Muayene, sigorta, MTV ve bakım tarihlerini Yapılacaklar'da takip et.",
            color: AppColors.warning
        ),
        OnboardingPage(
            icon: "tray.full",
            title: "Tüm kayıtların bir arada",
            description: "Bakım, masraf, belge ve ekspertiz geçmişini; yıllık maliyet raporlarını Kayıtlar'da gör.",
            color: AppColors.vehicle
        ),
        OnboardingPage(
            icon: "doc.richtext",
            title: "Satarken güven veren dosya oluştur",
            description: "Bakım ve belge geçmişinden paylaşılabilir satış dosyası oluştur.",
            color: AppColors.success
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Atla") {
                    completeOnboarding()
                }
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)
                .padding()
            }

            Spacer()

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    onboardingPageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Spacer()

            // CTA
            VStack(spacing: AppSpacing.md) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Devam" : "İlk aracımı ekle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .background(Color.appBackground)
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: page.icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(page.color)
            }
            .padding(.bottom, AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppSpacing.xl)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .accessibilityElement(children: .combine)
    }

    private func completeOnboarding() {
        onboardingCompleted = true
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Onboarding Wrapper
/// AppRouter'ı sarmalayan onboarding gate. İlk kurulumda onboarding gösterir.
struct OnboardingGate<Content: View>: View {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if onboardingCompleted {
                content
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView()
}
