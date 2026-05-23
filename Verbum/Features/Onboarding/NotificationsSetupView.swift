import SwiftUI

struct NotificationsSetupView: View {
    let onContinue: () -> Void
    @State private var count = 3

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Set up notifications")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xl * 2)

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
            .padding(.horizontal, AppSpacing.lg)

            // Count picker
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
                            .foregroundColor(AppColors.accent)
                    }

                    Text("\(count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 60)

                    Button {
                        if count < 10 { count += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            PillButton(title: "Allow & Save", action: onContinue)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}
