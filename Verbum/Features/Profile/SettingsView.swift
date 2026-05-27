import SwiftUI
import UIKit
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("soundEnabled") private var soundEnabled = true
    @State private var isRestoring = false
    @State private var showDeleteConfirm = false

    @State private var editingName = false
    @State private var nameInput = ""
    @State private var editingGender = false
    @State private var editingAge = false
    @State private var editingLanguage = false
    @State private var editingLevel = false
    @State private var editingWordsPerWeek = false
    @State private var wordsInput = ""
    @State private var editingDailyGoal = false
    @State private var dailyGoalInput: Double = 5
    @State private var showLevelTest = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        // PREMIUM
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
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .frame(width: 28)
                                    Text("Restore Purchases")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.textPrimary)
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
                            iconEditRow(icon: "person.2.fill", iconColor: .indigo, label: "Gender",
                                        value: userProfile.profile.gender?.rawValue ?? "Not set") { editingGender = true }
                            cardDivider
                            iconEditRow(icon: "calendar", iconColor: .orange, label: "Age",
                                        value: userProfile.profile.age?.rawValue ?? "Not set") { editingAge = true }
                            cardDivider
                            iconEditRow(icon: "globe", iconColor: .blue, label: "Native Language",
                                        value: userProfile.profile.nativeLanguage?.displayName ?? "Not set") { editingLanguage = true }
                            cardDivider
                            iconEditRow(icon: "chart.bar.fill", iconColor: .green, label: "Level",
                                        value: userProfile.profile.level.displayName) { editingLevel = true }
                            cardDivider
                            iconEditRow(icon: "target", iconColor: .orange, label: "Daily goal",
                                        value: "\(userProfile.profile.dailyGoal) words") {
                                dailyGoalInput = Double(userProfile.profile.dailyGoal)
                                editingDailyGoal = true
                            }
                        }

                        // SETTINGS
                        sectionLabel("Settings")
                        settingsCard {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.pink)
                                    .frame(width: 28)
                                Toggle("Sound", isOn: $soundEnabled)
                                    .font(.system(size: 16))
                                    .tint(AppColors.accent)
                            }
                            cardDivider
                            NavigationLink(destination: NotificationSettingsView().environmentObject(userProfile)) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.yellow)
                                        .frame(width: 28)
                                    Text("Notifications")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }

                        // DICTIONARY
                        sectionLabel("Dictionary")
                        settingsCard {
                            DatabaseStatusBanner()
                        }

                        // ACCOUNT
                        sectionLabel("Account")
                        settingsCard {
                            if auth.isSignedIn {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Signed in with Apple")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.textPrimary)
                                        if !userProfile.profile.name.isEmpty {
                                            Text(userProfile.profile.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.textSecondary)
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

                        // SOCIAL
                        sectionLabel("Community")
                        settingsCard {
                            iconRow(icon: "square.and.arrow.up", iconColor: AppColors.accent, label: "Share App") { shareApp() }
                            cardDivider
                            iconRow(icon: "star.fill", iconColor: .yellow, label: "Rate App") { rateApp() }
                            cardDivider
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
            .navigationTitle("Settings")
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
        .onAppear {
            nameInput = userProfile.profile.name
            wordsInput = "\(userProfile.profile.wordsPerWeek)"
        }
        .alert("Your Name", isPresented: $editingName) {
            TextField("Enter name", text: $nameInput)
            Button("Save") {
                let t = nameInput.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { userProfile.profile.name = t }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Words per week", isPresented: $editingWordsPerWeek) {
            TextField("Number (1–100)", text: $wordsInput)
                .keyboardType(.numberPad)
            Button("Save") {
                if let n = Int(wordsInput), n >= 1, n <= 100 {
                    userProfile.profile.wordsPerWeek = n
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How many words do you want to learn per week?")
        }
        .confirmationDialog("Select Gender", isPresented: $editingGender, titleVisibility: .visible) {
            ForEach(Gender.allCases, id: \.self) { g in
                Button(g.rawValue) { userProfile.profile.gender = g }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Select Age Range", isPresented: $editingAge, titleVisibility: .visible) {
            ForEach(AgeRange.allCases, id: \.self) { a in
                Button(a.rawValue) { userProfile.profile.age = a }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Select Level", isPresented: $editingLevel, titleVisibility: .visible) {
            ForEach(WordLevel.allCases, id: \.self) { l in
                Button(l.displayName) { userProfile.profile.level = l }
            }
            Button("Take Level Test") { showLevelTest = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showLevelTest) {
            LevelTestView().environmentObject(userProfile)
        }
        .sheet(isPresented: $editingLanguage) {
            LanguagePickerSheet(selected: userProfile.profile.nativeLanguage) { lang in
                userProfile.profile.nativeLanguage = lang
                editingLanguage = false
            }
        }
        .sheet(isPresented: $editingDailyGoal) {
            DailyGoalSheet(initial: userProfile.profile.dailyGoal) { newGoal in
                userProfile.profile.dailyGoal = newGoal
                editingDailyGoal = false
            } onCancel: {
                editingDailyGoal = false
            }
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive) {
                auth.deleteAccount()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all your progress, streaks, and settings. This cannot be undone.")
        }
    }

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
        VStack(spacing: AppSpacing.sm) {
            content()
        }
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
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func iconEditRow(icon: String, iconColor: Color, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 28)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.leading, 2)
            }
        }
    }

    private func shareApp() {
        let text = "Learn English with Verbum — a new word every day! 📖"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc)
    }

    private func rateApp() {
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id") {
            UIApplication.shared.open(url)
        }
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

// MARK: - Language Picker Sheet

private struct LanguagePickerSheet: View {
    let selected: NativeLanguage?
    let onSelect: (NativeLanguage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                List {
                    ForEach(NativeLanguage.allCases, id: \.self) { lang in
                        Button {
                            onSelect(lang)
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selected == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
            .navigationTitle("Native Language")
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
    }
}

// MARK: - Daily Goal Sheet

private struct DailyGoalSheet: View {
    @State private var value: Double
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    init(initial: Int, onSave: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        _value = State(initialValue: Double(initial))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: AppSpacing.xl) {
                    Spacer()
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.accent)
                    Text("\(Int(value))")
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: value)
                    Text("words per day")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                    Slider(value: $value, in: 1...30, step: 1)
                        .tint(AppColors.accent)
                        .padding(.horizontal, AppSpacing.lg)
                    HStack {
                        Text("Casual")
                        Spacer()
                        Text("Serious")
                        Spacer()
                        Text("Intense")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.lg)
                    Spacer()
                    PillButton(title: "Save") { onSave(Int(value)) }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
