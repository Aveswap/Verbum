import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingName = false
    @State private var nameInput = ""

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
                    row("Gender", value: userProfile.profile.gender?.rawValue ?? "Not set")
                    row("Age", value: userProfile.profile.age?.rawValue ?? "Not set")
                    row("Level", value: userProfile.profile.level.displayName)
                    row("Words per week", value: "\(userProfile.profile.wordsPerWeek)")
                }

                Section("SETTINGS") {
                    Toggle("Sound", isOn: .constant(true))
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
                    Button("Share App") {}
                        .foregroundColor(AppColors.textPrimary)
                    Button("Rate App") {}
                        .foregroundColor(AppColors.textPrimary)
                    Button("Follow us on Instagram") {}
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
        .alert("Your Name", isPresented: $editingName) {
            TextField("Enter name", text: $nameInput)
            Button("Save") {
                let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { userProfile.profile.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { nameInput = userProfile.profile.name }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value).foregroundColor(AppColors.textSecondary)
        }
    }
}
