import SwiftUI
import SwiftData

// MARK: - Community Create/Edit Post View
// Gönderi oluşturma ve düzenleme formu. Pro gate ile korunur.

struct CommunityCreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var communityAuth: CommunityAuthService
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    var editingPost: CommunityPost? = nil

    @State private var title = ""
    @State private var bodyText = ""
    @State private var postType: PostType?
    @State private var selectedTags: Set<String> = []
    @State private var showVehicle = false
    @State private var selectedPostVehicleId: UUID?
    @State private var validationErrors: [String] = []
    @State private var isSubmitting = false
    @State private var submitError: String?

    private let allTags = CommunityTag.all

    var body: some View {
        NavigationStack {
            Form {
                // Validation errors
                if !validationErrors.isEmpty {
                    Section("Düzeltilmesi Gerekenler") {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.critical)
                        }
                    }
                    .listRowBackground(AppColors.criticalBackground)
                }

                // Title
                Section {
                    TextField("Başlık (5-120 karakter)", text: $title)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(title.count)/120")
                        .font(AppTypography.caption)
                        .foregroundColor(title.count > 120 ? AppColors.critical : AppColors.textTertiary)
                } header: {
                    Text("Başlık")
                }

                // Body
                Section {
                    TextEditor(text: $bodyText)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minHeight: 140)
                        .overlay(alignment: .topLeading) {
                            if bodyText.isEmpty {
                                Text("İçerik (20-5000 karakter)")
                                    .font(AppTypography.body)
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                    Text("\(bodyText.count)/5000")
                        .font(AppTypography.caption)
                        .foregroundColor(bodyText.count > 5000 ? AppColors.critical : AppColors.textTertiary)
                } header: {
                    Text("İçerik")
                }

                // Post type
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: AppSpacing.xs) {
                        ForEach(PostType.allCases, id: \.self) { type in
                            Button {
                                postType = type
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: type.sfSymbol)
                                        .font(.caption)
                                    Text(type.displayName)
                                        .font(AppTypography.caption)
                                }
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .fill(postType == type ? AppColors.accentPrimary : AppColors.surfaceSecondary)
                                )
                                .foregroundColor(postType == type ? .white : AppColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Gönderi Türü")
                }

                // Tags
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: AppSpacing.xxs) {
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                Text(tag)
                                    .font(AppTypography.caption)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        Capsule()
                                            .fill(selectedTags.contains(tag) ? AppColors.accentPrimary : AppColors.surfaceSecondary)
                                    )
                                    .foregroundColor(selectedTags.contains(tag) ? .white : AppColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Etiketler (en az 1)")
                }

                // Vehicle info — kayıtlı araçlardan seçim
                Section {
                    Toggle("Aracımı gönderide göster", isOn: $showVehicle)
                    if showVehicle {
                        if vehicles.isEmpty {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "car")
                                    .font(.body)
                                    .foregroundColor(AppColors.textTertiary)
                                    .frame(width: 24)
                                Text("Henüz araç eklenmemiş")
                                    .font(AppTypography.secondary)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Text("Araç etiketi göstermek için önce Garaj'dan araç ekle.")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Picker("Araç", selection: $selectedPostVehicleId) {
                                Text("Araç seç").tag(nil as UUID?)
                                ForEach(vehicles) { vehicle in
                                    Text(postVehicleLabel(for: vehicle))
                                        .tag(vehicle.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppColors.accentPrimary)
                        }
                    }
                } header: {
                    Text("Araç Bilgisi (isteğe bağlı)")
                } footer: {
                    Text("Plaka bilgisini paylaşma. Yalnızca marka/model/yıl gösterilir.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                // Submit error
                if let submitError = submitError {
                    Section {
                        Text(submitError)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.critical)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(editingPost != nil ? "Gönderiyi Düzenle" : "Yeni Gönderi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingPost != nil ? "Güncelle" : "Paylaş") {
                        submit()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting)
                }
            }
            .onAppear {
                if let post = editingPost {
                    title = post.title
                    bodyText = post.body
                    postType = post.postType
                    selectedTags = Set(post.tags)
                    showVehicle = post.vehicleBrand != nil
                    // Düzenlemede mevcut post'un vehicle bilgisini koru
                    // (selectedPostVehicleId set edilmez — mevcut değerler submit'te kullanılır)
                } else if let profile = communityAuth.profile, profile.showVehicleOnPosts {
                    showVehicle = profile.showVehicleOnPosts
                    if let uuidString = UserDefaults.standard.string(forKey: "community_selected_vehicle_id"),
                       let uuid = UUID(uuidString: uuidString),
                       vehicles.contains(where: { $0.id == uuid }) {
                        selectedPostVehicleId = uuid
                    }
                }
            }
        }
    }

    /// Picker'da gösterilecek güvenli araç etiketi (plaka içermez).
    private func postVehicleLabel(for vehicle: Vehicle) -> String {
        var parts = [vehicle.brand, vehicle.model]
        if let year = vehicle.year { parts.append(String(year)) }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func submit() {
        let errors = CommunityPost.validate(
            title: title,
            body: bodyText,
            postType: postType,
            tags: Array(selectedTags)
        )

        guard errors.isValid else {
            validationErrors = errors.allErrors
            return
        }

        validationErrors = []
        isSubmitting = true
        submitError = nil

        Task {
            do {
                // Seçili araçtan marka/model/yıl türet
                let selectedVehicle = selectedPostVehicleId.flatMap { id in vehicles.first { $0.id == id } }

                if let existing = editingPost {
                    try await CommunityService.shared.updatePost(
                        id: existing.id,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                        postType: postType!,
                        tags: Array(selectedTags),
                        vehicleBrand: showVehicle ? (selectedVehicle?.brand ?? existing.vehicleBrand) : nil,
                        vehicleModel: showVehicle ? (selectedVehicle?.model ?? existing.vehicleModel) : nil,
                        vehicleYear: showVehicle ? (selectedVehicle?.year ?? existing.vehicleYear) : nil
                    )
                } else {
                    _ = try await CommunityService.shared.createPost(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
                        postType: postType!,
                        tags: Array(selectedTags),
                        vehicleBrand: showVehicle ? selectedVehicle?.brand : nil,
                        vehicleModel: showVehicle ? selectedVehicle?.model : nil,
                        vehicleYear: showVehicle ? selectedVehicle?.year : nil
                    )
                }
                dismiss()
            } catch {
                #if DEBUG
                print("[CommunityCreatePost] Submit error: \(error.localizedDescription)")
                #endif
                submitError = "Bu işlem için Arvia Pro gerekli olabilir. Satın alımını geri yüklemeyi deneyebilirsin."
            }
            isSubmitting = false
        }
    }
}
