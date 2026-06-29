import SwiftUI

// MARK: - Report Target

struct ReportTarget: Identifiable {
    let id = UUID()
    let type: String
    let targetId: UUID
}

// MARK: - Report Reason Sheet
// Kullanıcıya şikayet sebebi seçtiren alt ekran.

struct ReportReasonSheet: View {
    let targetType: String
    let targetId: UUID
    let onDismiss: () -> Void

    @State private var selectedReason: ReportReason?
    @State private var description: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if didSubmit {
                    Section {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(AppColors.success)

                            Text("Bildiriminiz alındı")
                                .font(AppTypography.cardTitle)
                                .foregroundColor(AppColors.textPrimary)

                            Text("Ekibimiz en kısa sürede inceleyecek.")
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                    }
                } else {
                    Section {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Image(systemName: reason.sfSymbol)
                                        .font(.body)
                                        .foregroundColor(AppColors.textSecondary)
                                        .frame(width: 28)
                                    Text(reason.displayName)
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColors.accentPrimary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Bildirim Sebebi")
                    }

                    if selectedReason == .other {
                        Section {
                            TextField("Açıklama (isteğe bağlı)", text: $description, axis: .vertical)
                                .font(AppTypography.secondary)
                                .lineLimit(3...6)
                        } header: {
                            Text("Açıklama")
                        }
                    }

                    if let error = error {
                        Section {
                            Text(error)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.critical)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !didSubmit {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("İptal") { onDismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gönder") { submit() }
                            .disabled(selectedReason == nil || isSubmitting)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kapat") { onDismiss() }
                    }
                }
            }
        }
    }

    private func submit() {
        guard let reason = selectedReason else { return }
        isSubmitting = true
        error = nil
        Task {
            do {
                try await CommunityModerationService.shared.submitReport(
                    targetType: targetType,
                    targetId: targetId,
                    reason: reason,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description
                )
                didSubmit = true
            } catch {
                self.error = "Bildirim gönderilemedi: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }
}
