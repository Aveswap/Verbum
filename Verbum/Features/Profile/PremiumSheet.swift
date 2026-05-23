import SwiftUI

struct PremiumSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("infinity",          "Unlimited Words",     "Access all 50,000+ words in our library"),
        ("gamecontroller.fill","All Practice Games",  "Unlock every game mode and challenge"),
        ("rectangle.grid.2x2","All Categories",      "Professional, science, medicine & more"),
        ("crown.fill",        "Premium Themes",      "Beautiful themes for every mood"),
        ("bell.badge.fill",   "Smart Reminders",     "Personalized notification schedule"),
        ("chart.line.uptrend.xyaxis", "Detailed Stats", "Deep insights into your progress"),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.4), AppColors.background],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 220)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(AppSpacing.md)
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 52))
                            .foregroundColor(AppColors.accent)
                            .padding(.top, AppSpacing.xl)

                        Text("Verbum Premium")
                            .font(.custom("Georgia-Bold", size: 28))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Learn without limits")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.lg)
                }

                // Features list
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(features, id: \.title) { feature in
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    Text(feature.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(AppSpacing.cornerRadius)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }

                // CTA
                VStack(spacing: AppSpacing.sm) {
                    PricingRow(period: "Weekly", price: "$2.99")
                    PricingRow(period: "Monthly", price: "$7.99", isHighlighted: true, badge: "Most Popular")
                    PricingRow(period: "Yearly", price: "$39.99", note: "= $3.33/mo")

                    Button {
                        HapticManager.impact(.medium)
                        dismiss()
                    } label: {
                        Text("Start 3-Day Free Trial")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppColors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.accentButton)
                            .clipShape(Capsule())
                    }
                    .padding(.top, AppSpacing.sm)

                    HStack(spacing: AppSpacing.lg) {
                        Button("Restore") {}
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        Button("Privacy Policy") {}
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        Button("Terms of Use") {}
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PricingRow: View {
    let period: String
    let price: String
    var isHighlighted = false
    var badge: String? = nil
    var note: String? = nil

    var body: some View {
        HStack {
            if isHighlighted {
                Image(systemName: "circle.inset.filled")
                    .foregroundColor(AppColors.accent)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(period)
                .font(.system(size: 15, weight: isHighlighted ? .semibold : .regular))
                .foregroundColor(AppColors.textPrimary)

            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.accent)
                    .cornerRadius(8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(price)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(isHighlighted ? AppColors.accent.opacity(0.12) : AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                .stroke(isHighlighted ? AppColors.accent : Color.clear, lineWidth: 1.5)
        )
    }
}
