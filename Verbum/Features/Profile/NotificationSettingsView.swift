import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @State private var count = 3
    @State private var enabled = true
    @State private var saved = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {

                // Preview card
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppColors.accent)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Verbum")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Your word of the day is ready! 📖")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("now")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.cornerRadius)

                // Enable toggle
                Toggle(isOn: $enabled) {
                    Text("Enable Notifications")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary)
                }
                .tint(AppColors.accent)
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.cornerRadius)

                // Count stepper
                VStack(spacing: AppSpacing.sm) {
                    Text("Notifications per day")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 14))

                    HStack(spacing: AppSpacing.xl) {
                        Button {
                            if count > 1 { count -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(enabled ? AppColors.accent : AppColors.locked)
                        }
                        .disabled(!enabled)

                        Text("\(count)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 60)

                        Button {
                            if count < 10 { count += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(enabled ? AppColors.accent : AppColors.locked)
                        }
                        .disabled(!enabled)
                    }

                    Text("Spread between 9 AM and 10 PM")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.cornerRadius)
                .opacity(enabled ? 1 : 0.5)

                Spacer()

                Button {
                    userProfile.profile.notificationsEnabled = enabled
                    userProfile.profile.notificationCount = count
                    if enabled {
                        let startHour = NotificationManager.hoursFrom(userProfile.profile.notificationStart)
                        let endHour   = NotificationManager.hoursFrom(userProfile.profile.notificationEnd)
                        NotificationManager.requestAndSchedule(count: count, startHour: startHour, endHour: endHour, seenIds: Set(userProfile.profile.seenWordIds))
                    } else {
                        NotificationManager.cancelAll()
                    }
                    HapticManager.success()
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { saved = false }
                    }
                } label: {
                    Text(saved ? "Saved ✓" : "Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(saved ? Color.green.opacity(0.8) : AppColors.accent)
                        .cornerRadius(AppSpacing.pillRadius)
                        .animation(.easeInOut(duration: 0.2), value: saved)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(AppSpacing.md)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            count = userProfile.profile.notificationCount
            enabled = userProfile.profile.notificationsEnabled
        }
    }
}
