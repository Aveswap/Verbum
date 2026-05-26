import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.surface)
                    .frame(width: 220, height: 220)
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 90))
                    .foregroundColor(AppColors.accent)
            }

            VStack(spacing: AppSpacing.sm) {
                Text("Expand Your\nVocabulary")
                    .font(AppTypography.heroTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Learn new words every day in just 1 minute")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            HStack(spacing: 0) {
                StatColumn(value: "1,000+", label: "Words")
                Rectangle().fill(AppColors.surface).frame(width: 1, height: 40)
                StatColumn(value: "100%", label: "Offline")
                Rectangle().fill(AppColors.surface).frame(width: 1, height: 40)
                StatColumn(value: "0 Ads", label: "Free")
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)

            PillButton(title: "Get Started", action: onStart)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}

private struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
