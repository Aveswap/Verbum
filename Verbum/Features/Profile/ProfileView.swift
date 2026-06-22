import SwiftUI
import UIKit
import AuthenticationServices

/// The top-left feed icon opens this single hub: profile (premium + vocabulary) merged with the
/// app settings (premium management, about you, sound, notifications, account, community).
/// No Practice here (it lives in the feed's bottom row); no gameplay/quiz toggle; no dictionary.
struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var showFavorites = false
    @State private var showHistory = false
    @State private var showLiked = false
    @State private var showPremium = false
    @State private var isRestoring = false
    @State private var showDeleteConfirm = false
    @State private var editingName = false
    @State private var nameInput = ""
    @State private var editingDailyGoal = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        if subscriptions.isPro { premiumActiveCard } else { premiumCard }
                        vocabularySection

                        // PREMIUM (manage)
                        sectionLabel("Premium")
                        settingsCard {
                            iconRow(icon: "crown.fill", iconColor: AppColors.accent, label: "Manage Subscription") {
                                if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            cardDivider
                            Button {
                                isRestoring = true
                                Task { await subscriptions.restorePurchases(); isRestoring = false }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16)).foregroundColor(.blue).frame(width: 28)
                                    Text("Restore Purchases")
                                        .font(.system(size: 16)).foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    if isRestoring { ProgressView().tint(AppColors.accent) }
                                    else { Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textSecondary) }
                                }
                            }
                            .disabled(isRestoring)
                            if let error = subscriptions.purchaseError {
                                Text(error).font(.system(size: 12)).foregroundColor(.red).padding(.leading, 36)
                            }
                        }

                        // ABOUT YOU
                        sectionLabel("About You")
                        settingsCard {
                            iconEditRow(icon: "person.fill", iconColor: .purple, label: "Name",
                                        value: userProfile.profile.name.isEmpty ? "Not set" : userProfile.profile.name) { editingName = true }
                            cardDivider
                            iconEditRow(icon: "target", iconColor: .orange, label: "Daily goal",
                                        value: "\(userProfile.profile.dailyGoal) words") { editingDailyGoal = true }
                        }

                        // SETTINGS (sound + notifications — no gameplay/quizzes, no dictionary)
                        sectionLabel("Settings")
                        settingsCard {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 16)).foregroundColor(.pink).frame(width: 28)
                                Toggle("Sound", isOn: $soundEnabled).font(.system(size: 16)).tint(AppColors.accent)
                            }
                            cardDivider
                            NavigationLink(destination: NotificationSettingsView().environmentObject(userProfile)) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16)).foregroundColor(.yellow).frame(width: 28)
                                    Text("Notifications")
                                        .font(.system(size: 16)).foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }

                        // ACCOUNT — hidden while auth is a local-dev stub (AppInfo.isSignInConfigured).
                        if AppInfo.isSignInConfigured {
                            sectionLabel("Account")
                            settingsCard {
                                if auth.isSignedIn {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 16)).foregroundColor(AppColors.textPrimary).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Signed in with Apple")
                                                .font(.system(size: 16)).foregroundColor(AppColors.textPrimary)
                                            if !userProfile.profile.name.isEmpty {
                                                Text(userProfile.profile.name)
                                                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.seal.fill").foregroundColor(AppColors.accent)
                                    }
                                    cardDivider
                                    Button { auth.signOut() } label: {
                                        HStack(spacing: AppSpacing.sm) {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 16)).foregroundColor(.red).frame(width: 28)
                                            Text("Sign Out").font(.system(size: 16)).foregroundColor(.red)
                                            Spacer()
                                        }
                                    }
                                } else {
                                    SignInWithAppleButton(.signIn) { request in
                                        request.requestedScopes = [.fullName, .email]
                                    } onCompletion: { result in
                                        auth.handleSignInResult(result)
                                    }
                                    .signInWithAppleButtonStyle(.white)
                                    .frame(height: 44)
                                    .cornerRadius(AppSpacing.cornerRadius)
                                }
                                if let error = auth.error {
                                    Text(error).font(.system(size: 12)).foregroundColor(.red)
                                }
                                cardDivider
                                Button { showDeleteConfirm = true } label: {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 16)).foregroundColor(.red).frame(width: 28)
                                        Text("Delete Account").font(.system(size: 16)).foregroundColor(.red)
                                        Spacer()
                                    }
                                }
                            }
                        }

                        // COMMUNITY
                        sectionLabel("Community")
                        settingsCard {
                            if AppInfo.isStoreIDConfigured {
                                iconRow(icon: "square.and.arrow.up", iconColor: AppColors.accent, label: "Share App") { shareApp() }
                                cardDivider
                                iconRow(icon: "star.fill", iconColor: .yellow, label: "Rate App") { rateApp() }
                                cardDivider
                            }
                            iconRow(icon: "camera.fill", iconColor: .pink, label: "Follow us on Instagram") { openInstagram() }
                        }

                        #if DEBUG
                        sectionLabel("Developer")
                        settingsCard {
                            Button {
                                userProfile.resetOnboarding()
                                dismiss()
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 16)).foregroundColor(.red).frame(width: 28)
                                    Text("Reset Onboarding").font(.system(size: 16)).foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                        #endif

                        Text("Verbum v1.0.0")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle(userProfile.profile.name.isEmpty ? "Profile" : "Hi, \(userProfile.profile.name) 👋")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { nameInput = userProfile.profile.name }
        .sheet(isPresented: $showFavorites)  { FavoritesView().environmentObject(userProfile) }
        .sheet(isPresented: $showLiked)      { LikedView().environmentObject(userProfile) }
        .sheet(isPresented: $showHistory)    { HistoryView().environmentObject(userProfile) }
        .sheet(isPresented: $showPremium)    { PremiumSheet().environmentObject(subscriptions) }
        .alert("Your Name", isPresented: $editingName) {
            TextField("Enter name", text: $nameInput)
            Button("Save") {
                let t = nameInput.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { userProfile.profile.name = t }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $editingDailyGoal) {
            DailyGoalSheet(initial: userProfile.profile.dailyGoal) { newGoal in
                userProfile.profile.dailyGoal = newGoal
                editingDailyGoal = false
            } onCancel: {
                editingDailyGoal = false
            }
        }
        .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete All Data", role: .destructive) {
                auth.deleteAccount { success in if success { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all your progress, streaks, and settings. This cannot be undone.")
        }
    }

    // MARK: - Premium cards
    private var premiumCard: some View {
        Button { showPremium = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Go Premium")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                    Text("Unlock all words & practice modes")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textOnAccent.opacity(0.8))
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textOnAccent.opacity(0.5))
            }
            .padding(AppSpacing.md)
            .background(AppColors.accent)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }

    private var premiumActiveCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill").foregroundColor(AppColors.textOnAccent)
                    Text("Verbum Premium")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                }
                Text("All words and features unlocked")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textOnAccent.opacity(0.85))
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textOnAccent.opacity(0.8))
        }
        .padding(AppSpacing.md)
        .background(AppColors.accent)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    // MARK: - Vocabulary
    private var vocabularySection: some View {
        ProfileSection(title: "YOUR VOCABULARY") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                Button { showFavorites = true } label: {
                    SettingCard(title: "Favorites", badge: "\(userProfile.profile.bookmarkedWordIds.count)")
                }
                Button { showLiked = true } label: {
                    SettingCard(title: "Liked", badge: "\(userProfile.profile.likedWordIds.count)")
                }
                Button { showHistory = true } label: {
                    SettingCard(title: "History", badge: "\(userProfile.profile.seenWordIds.count)")
                }
            }
        }
    }

    // MARK: - Settings row helpers
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.top, AppSpacing.xs)
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: AppSpacing.sm) { content() }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
    }

    private var cardDivider: some View {
        Divider().background(AppColors.surfaceSecondary)
    }

    private func iconRow(icon: String, iconColor: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16)).foregroundColor(iconColor).frame(width: 28)
                Text(label)
                    .font(.system(size: 16)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func iconEditRow(icon: String, iconColor: Color, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16)).foregroundColor(iconColor).frame(width: 28)
                Text(LocalizedStringKey(label))
                    .font(.system(size: 16)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(LocalizedStringKey(value))
                    .font(.system(size: 15)).foregroundColor(AppColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundColor(AppColors.textSecondary).padding(.leading, 2)
            }
        }
    }

    private func shareApp() {
        let text = "Learn English with Verbum — a new word every day! 📖"
        present(UIActivityViewController(activityItems: [text], applicationActivities: nil))
    }

    private func rateApp() {
        UIApplication.shared.open(AppInfo.rateURL)
    }

    private func openInstagram() {
        if let url = URL(string: "https://instagram.com/verbumapp") {
            UIApplication.shared.open(url)
        }
    }

    private func present(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        root.present(vc, animated: true)
    }
}

// MARK: - Sub-components
private struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            content
        }
    }
}

private struct SettingCard: View {
    let title: String
    var badge: String? = nil
    var icon: String? = nil
    var locked: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(locked ? AppColors.locked : AppColors.accent)
                    .frame(width: 18)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(locked ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
            Spacer()
            if let badge, badge != "0" {
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accent)
                    .cornerRadius(10)
            }
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(locked ? AppColors.locked : AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(height: 50)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}
