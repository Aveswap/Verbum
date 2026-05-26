import SwiftUI
import StoreKit

struct PremiumSheet: View {
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("infinity",          "Master 1,000 Words",         "Curated by linguists to maximize retention"),
        ("gamecontroller.fill","Practice Until You're Fluent","No daily caps — play as much as you want"),
        ("rectangle.grid.2x2","Every Domain, Explored",     "From Law to Art to Medicine and beyond"),
        ("bell.badge.fill",   "Smart Reminders",            "Personalized schedule that keeps you on track"),
        ("chart.line.uptrend.xyaxis", "Deep Progress Insights", "See exactly how your vocabulary is growing"),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                featuresList
                ctaSection
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
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
    }

    // MARK: - Features

    private var featuresList: some View {
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
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: AppSpacing.sm) {
            if subscriptions.isLoading {
                ProgressView().tint(AppColors.accent)
                    .padding()
            } else {
                productRows
            }

            purchaseButton

            if let error = subscriptions.purchaseError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            footerLinks
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Product rows

    @State private var selectedProductID: String = SubscriptionManager.yearlyID

    private var productRows: some View {
        VStack(spacing: AppSpacing.xs) {
            if let monthly = subscriptions.monthlyProduct {
                ProductRow(
                    product: monthly,
                    isSelected: selectedProductID == monthly.id,
                    badge: nil,
                    note: "$4.99/mo"
                ) { selectedProductID = monthly.id }
            } else {
                ProductRow(id: SubscriptionManager.monthlyID, price: "$4.99", period: "Monthly",
                           isSelected: selectedProductID == SubscriptionManager.monthlyID,
                           badge: nil, note: "$4.99/mo") {
                    selectedProductID = SubscriptionManager.monthlyID
                }
            }

            if let yearly = subscriptions.yearlyProduct {
                ProductRow(
                    product: yearly,
                    isSelected: selectedProductID == yearly.id,
                    badge: "Best Value",
                    note: "$2.08/mo · Save 58%"
                ) { selectedProductID = yearly.id }
            } else {
                ProductRow(id: SubscriptionManager.yearlyID, price: "$24.99", period: "Yearly",
                           isSelected: selectedProductID == SubscriptionManager.yearlyID,
                           badge: "Best Value", note: "$2.08/mo · Save 58%") {
                    selectedProductID = SubscriptionManager.yearlyID
                }
            }

            if let lifetime = subscriptions.lifetimeProduct {
                ProductRow(
                    product: lifetime,
                    isSelected: selectedProductID == lifetime.id,
                    badge: nil,
                    note: "One-time purchase"
                ) { selectedProductID = lifetime.id }
            } else {
                ProductRow(id: SubscriptionManager.lifetimeID, price: "$59.99", period: "Lifetime",
                           isSelected: selectedProductID == SubscriptionManager.lifetimeID,
                           badge: nil, note: "One-time purchase") {
                    selectedProductID = SubscriptionManager.lifetimeID
                }
            }
        }
    }

    // MARK: - Purchase button

    private var selectedProduct: Product? {
        subscriptions.products.first { $0.id == selectedProductID }
    }

    private var hasFreeTrial: Bool {
        guard selectedProductID != SubscriptionManager.lifetimeID else { return false }
        return selectedProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private var ctaTitle: String {
        if selectedProductID == SubscriptionManager.lifetimeID { return "Get Lifetime Access" }
        return hasFreeTrial ? "Start Free Trial" : "Subscribe Now"
    }

    private var purchaseButton: some View {
        VStack(spacing: AppSpacing.xs) {
            Button {
                HapticManager.impact(.medium)
                Task {
                    if let product = selectedProduct {
                        await subscriptions.purchase(product)
                        if subscriptions.isPro { dismiss() }
                    }
                }
            } label: {
                Text(ctaTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.accentButton)
                    .clipShape(Capsule())
            }
            .padding(.top, AppSpacing.sm)

            if selectedProductID != SubscriptionManager.lifetimeID {
                Text(hasFreeTrial
                     ? "Free trial, then auto-renews. Cancel anytime in Apple ID settings at least 24 hours before renewal."
                     : "Auto-renews. Cancel anytime in Apple ID settings at least 24 hours before renewal.")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: AppSpacing.lg) {
            Button("Restore") {
                Task { await subscriptions.restorePurchases() }
            }
            .font(.system(size: 12))
            .foregroundColor(AppColors.textSecondary)

            Link("Privacy Policy",
                 destination: URL(string: "https://verbum.app/privacy")!)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)

            Link("Terms of Use",
                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - ProductRow

private struct ProductRow: View {
    let period: String
    let price: String
    let isSelected: Bool
    var badge: String? = nil
    var note: String? = nil
    let onTap: () -> Void

    init(product: Product, isSelected: Bool, badge: String?, note: String?, onTap: @escaping () -> Void) {
        self.period = product.displayName
        self.price = product.displayPrice
        self.isSelected = isSelected
        self.badge = badge
        self.note = note
        self.onTap = onTap
    }

    init(id: String, price: String, period: String, isSelected: Bool, badge: String?, note: String?, onTap: @escaping () -> Void) {
        self.period = period
        self.price = price
        self.isSelected = isSelected
        self.badge = badge
        self.note = note
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)

                Text(period)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(AppColors.textPrimary)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
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
            .background(isSelected ? AppColors.accent.opacity(0.12) : AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                    .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
            )
        }
    }
}
