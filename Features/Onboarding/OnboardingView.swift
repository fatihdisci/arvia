import SwiftUI

// MARK: - Onboarding View
// İlk kurulumda gösterilen 4 ekranlı rehber. Premium, sakin, Apple-native.
// Emoji yok, mavi-mor gradient yok, gereksiz illüstrasyon yok.

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    @State private var currentPage = 0
    @State private var showAddVehicle = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "car.fill",
            title: "Aracına iyi bak.",
            description: "Muayene, sigorta, bakım, masraf ve belgelerini tek yerde takip et.",
            color: AppColors.accentPrimary
        ),
        OnboardingPage(
            icon: "checklist",
            title: "Yapılacakları kaçırma",
            description: "Muayene, sigorta, MTV ve bakım tarihlerini Yapılacaklar'da takip et.",
            color: AppColors.warning
        ),
        OnboardingPage(
            icon: "clock.arrow.circlepath",
            title: "Geçmişini düzenli tut",
            description: "Bakım, masraf, belge ve ekspertiz kayıtlarını Geçmiş'te sakla.",
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

                // Page dots indicator
                HStack(spacing: AppSpacing.xs) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? AppColors.accentPrimary : AppColors.border)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showAddVehicle) {
            VehicleFormView()
        }
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
        showAddVehicle = true
        dismiss()
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
