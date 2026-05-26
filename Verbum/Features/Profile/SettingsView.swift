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
    @State private var showLevelTest = false

    var body: some View {
        NavigationView {
            List {
                Section("PREMIUM") {
                    Button("Manage Subscription") {
                        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(AppColors.textPrimary)

                    Button {
                        isRestoring = true
                        Task {
                            await subscriptions.restorePurchases()
                            isRestoring = false
                        }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                                .foregroundColor(AppColors.textPrimary)
                            if isRestoring {
                                Spacer()
                                ProgressView().tint(AppColors.accent)
                            }
                        }
                    }
                    .disabled(isRestoring)

                    if let error = subscriptions.purchaseError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }

                Section("ABOUT YOU") {
                    Button { editingName = true } label: {
                        row("Name", value: userProfile.profile.name.isEmpty ? "Not set" : userProfile.profile.name)
                    }
                    Button { editingGender = true } label: {
                        row("Gender", value: userProfile.profile.gender?.rawValue ?? "Not set")
                    }
                    Button { editingAge = true } label: {
                        row("Age", value: userProfile.profile.age?.rawValue ?? "Not set")
                    }
                    Button { editingLanguage = true } label: {
                        row("Native Language", value: userProfile.profile.nativeLanguage?.displayName ?? "Not set")
                    }
                    Button { editingLevel = true } label: {
                        row("Level", value: userProfile.profile.level.displayName)
                    }
                    Button { editingWordsPerWeek = true } label: {
                        row("Words per week", value: "\(userProfile.profile.wordsPerWeek)")
                    }
                }

                Section("SETTINGS") {
                    Toggle("Sound", isOn: $soundEnabled)
                        .tint(AppColors.accent)
                    NavigationLink("Notifications") {
                        NotificationSettingsView().environmentObject(userProfile)
                    }
                }

                Section("DICTIONARY") {
                    DatabaseStatusBanner()
                }

                Section("ACCOUNT") {
                    if auth.isSignedIn {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signed in with Apple")
                                    .foregroundColor(AppColors.textPrimary)
                                if !userProfile.profile.name.isEmpty {
                                    Text(userProfile.profile.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(AppColors.accent)
                        }
                        Button("Sign Out") { auth.signOut() }
                            .foregroundColor(.red)
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
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    Button("Delete Account") { showDeleteConfirm = true }
                        .foregroundColor(.red)
                }

                Section {
                    Button("Share App") { shareApp() }
                        .foregroundColor(AppColors.textPrimary)
                    Button("Rate App") { rateApp() }
                        .foregroundColor(AppColors.textPrimary)
                    Button("Follow us on Instagram") { openInstagram() }
                        .foregroundColor(AppColors.textPrimary)
                }

                #if DEBUG
                Section("DEVELOPER") {
                    Button("Reset Onboarding") {
                        userProfile.resetOnboarding()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                #endif

                Section {
                    HStack {
                        Spacer()
                        Text("Verbum v1.0.0")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
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

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value).foregroundColor(AppColors.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .padding(.leading, 2)
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
