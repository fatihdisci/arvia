import SwiftUI

// MARK: - Brand Intro View
// Uygulama açıldığında kısa, premium bir ilk render deneyimi.
// iOS Launch Screen'i statik kalır — bu görünüm app açıldıktan SONRA gösterilir.
// Kısa, tatlı, Apple-native. Oyun intro'su gibi değil.

struct BrandIntroView<Content: View>: View {
    let content: Content
    let showIntro: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: IntroPhase = .hidden
    @AppStorage("brandIntroShown") private var introShown = false

    private enum IntroPhase {
        case hidden
        case appearing
        case shown
    }

    init(showIntro: Bool = true, @ViewBuilder content: () -> Content) {
        self.showIntro = showIntro && !UserDefaults.standard.bool(forKey: "brandIntroShown")
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(phase == .shown ? 1 : 0)

            if phase != .shown {
                introOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            if showIntro && !reduceMotion {
                runIntro()
            } else if showIntro {
                // Reduce Motion açık: intro'yu atla, direkt content'e geç
                phase = .shown
                UserDefaults.standard.set(true, forKey: "brandIntroShown")
            } else {
                phase = .shown
            }
        }
    }

    // MARK: - Intro Overlay
    private var introOverlay: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Hero icon — calm, premium
                ZStack {
                    Circle()
                        .fill(AppColors.accentPrimary.opacity(0.08))
                        .frame(width: 100, height: 100)

                    Image(systemName: "car.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(AppColors.accentPrimary)
                }
                .scaleEffect(phase == .appearing ? 1.0 : 0.6)
                .opacity(phase == .appearing ? 1 : 0)

                // App name + tagline
                VStack(spacing: AppSpacing.xxs) {
                    Text(AppBrand.appName)
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary)

                    Text("Aracının dijital yaşam dosyası")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .opacity(phase == .appearing ? 1 : 0)
                .offset(y: phase == .appearing ? 0 : 8)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Animation Sequence
    private func runIntro() {
        withAnimation(.easeOut(duration: 0.6)) {
            phase = .appearing
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.35)) {
                phase = .shown
            }
            UserDefaults.standard.set(true, forKey: "brandIntroShown")
        }
    }
}

// MARK: - Preview

#Preview("Brand Intro") {
    BrandIntroView {
        Text("App Content")
            .font(.largeTitle)
    }
}
