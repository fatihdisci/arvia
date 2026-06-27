import SwiftUI

// MARK: - Yapılacaklar (Todos) Tab
// Gelecekte yapılacak işler/hatırlatıcılar.
// Odak: "ne yapmam gerekiyor?"

struct TodosView: View {
    @State private var showAddReminder = false
    @State private var showNotificationPrompt = false

    var body: some View {
        NavigationStack {
            ReminderListView()
                .navigationTitle("Yapılacaklar")
                .background(Color.appBackground)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showAddReminder = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body)
                                .foregroundColor(AppColors.accentPrimary)
                        }
                        .accessibilityLabel("Yapılacak Ekle")
                    }
                }
                .sheet(isPresented: $showAddReminder) {
                    ReminderFormView()
                }
        }
        .onAppear {
            checkNotificationPermission()
        }
        .sheet(isPresented: $showNotificationPrompt) {
            notificationPermissionSheet
        }
    }

    // MARK: - Notification Permission
    private func checkNotificationPermission() {
        Task {
            let status = await NotificationService.shared.currentAuthorizationStatus()
            if status == .notDetermined {
                await MainActor.run { showNotificationPrompt = true }
            }
        }
    }

    private var notificationPermissionSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(AppColors.accentPrimary)
                .padding(.bottom, AppSpacing.sm)
            VStack(spacing: AppSpacing.xs) {
                Text("Önemli tarihleri kaçırma")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Muayene, sigorta ve bakım gibi önemli araç tarihlerini sana hatırlatmamız için bildirim göndermemize izin ver. Reklam veya gereksiz bildirim göndermiyoruz.")
                    .font(AppTypography.secondary)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            VStack(spacing: AppSpacing.sm) {
                Button { requestSystemPermission() } label: {
                    Text("Bildirimlere İzin Ver").frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .padding(.horizontal, AppSpacing.xxl)
                Button { showNotificationPrompt = false } label: {
                    Text("Şimdi Değil")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.top, AppSpacing.md)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .presentationDetents([.medium])
    }

    private func requestSystemPermission() {
        Task {
            _ = await NotificationService.shared.requestAuthorization()
            await MainActor.run { showNotificationPrompt = false }
        }
    }
}

#Preview("Yapılacaklar — Boş") { TodosView() }
#Preview("Yapılacaklar — Dolu") { TodosView().modelContainer(MockDataProvider.previewContainer) }
