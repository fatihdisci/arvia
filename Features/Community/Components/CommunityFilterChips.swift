import SwiftUI

// MARK: - Community Filter Chips
// Post tipi ve etiket filtreleme bileşenleri.

struct CommunityFilterChips: View {
    @Binding var selectedType: PostType?
    @Binding var selectedTags: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Post tipi filtreleri
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    FilterChip(
                        label: "Tümü",
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )

                    ForEach(PostType.allCases, id: \.self) { type in
                        FilterChip(
                            label: type.displayName,
                            icon: type.sfSymbol,
                            isSelected: selectedType == type,
                            action: { selectedType = type }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
            .trailingScrollFade()

            // Etiket filtreleri
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(CommunityTag.all, id: \.self) { tag in
                        FilterChip(
                            label: tag,
                            isSelected: selectedTags.contains(tag),
                            action: { toggleTag(tag) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.screenMarginH)
            }
            .trailingScrollFade()
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(AppTypography.captionMedium)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.accentPrimary : Color.appSurface)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
            )
            .foregroundColor(isSelected ? AppColors.textOnAccent : AppColors.textSecondary)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Seçili" : "Filtrelemek için iki kere dokun")
    }
}

// MARK: - Preview

#Preview("Filter Chips") {
    VStack {
        CommunityFilterChips(
            selectedType: .constant(nil),
            selectedTags: .constant(["Bakım"])
        )
        CommunityFilterChips(
            selectedType: .constant(.advice),
            selectedTags: .constant(["Bakım", "Sigorta"])
        )
    }
    .padding(.vertical)
    .background(Color.appBackground)
}

// MARK: - Trailing Scroll Fade
// Yatay chip listesi ekran kenarında kesildiğinde "devamı var" sinyali —
// sağ kenarda arka plana karışan kısa bir fade.
private extension View {
    func trailingScrollFade(width: CGFloat = 28) -> some View {
        overlay(alignment: .trailing) {
            LinearGradient(
                colors: [Color.appBackground.opacity(0), Color.appBackground],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width)
            .allowsHitTesting(false)
        }
    }
}
