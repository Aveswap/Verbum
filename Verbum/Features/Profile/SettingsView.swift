import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("soundEnabled") private var soundEnabled = true

    @State private var editingName = false
    @State private var nameInput = ""
    @State private var editingGender = false
    @State private var editingAge = false
    @State private var editingLevel = false
    @State private var editingWordsPerWeek = false
    @State private var wordsInput = ""
    @State private var showLevelTest = false

    var body: some View {
        NavigationView {
            List {
                Section("PREMIUM") {
                    NavigationLink("Manage Subscription") { EmptyView() }
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
                    NavigationLink("Language") { EmptyView() }
                    NavigationLink("Notifications") {
                        NotificationSettingsView().environmentObject(userProfile)
                    }
                }

                Section("ACCOUNT") {
                    NavigationLink("Sign In") { EmptyView() }
                }

                Section {
                    Button("Share App") { shareApp() }
                        .foregroundColor(AppColors.textPrimary)
                    Button("Rate App") { rateApp() }
                        .foregroundColor(AppColors.textPrimary)
                    Button("Follow us on Instagram") { openInstagram() }
                        .foregroundColor(AppColors.textPrimary)
                }

                Section("DEVELOPER") {
                    Button("Reset Onboarding") {
                        userProfile.resetOnboarding()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

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
        // Name
        .alert("Your Name", isPresented: $editingName) {
            TextField("Enter name", text: $nameInput)
            Button("Save") {
                let t = nameInput.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { userProfile.profile.name = t }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Words per week
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
        // Gender
        .confirmationDialog("Select Gender", isPresented: $editingGender, titleVisibility: .visible) {
            ForEach(Gender.allCases, id: \.self) { g in
                Button(g.rawValue) { userProfile.profile.gender = g }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Age
        .confirmationDialog("Select Age Range", isPresented: $editingAge, titleVisibility: .visible) {
            ForEach(AgeRange.allCases, id: \.self) { a in
                Button(a.rawValue) { userProfile.profile.age = a }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Level
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

    // MARK: - Actions
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
