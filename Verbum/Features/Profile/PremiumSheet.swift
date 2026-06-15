import SwiftUI
import StoreKit

struct PremiumSheet: View {
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("infinity",          "Unlock Every Word",          "The full collection of rare, beautiful words"),
        ("gamecontroller.fill","Practice Until You're Fluent","No daily caps — play as much as you want"),
        ("rectangle.grid.2x2","Every Domain, Explored",     "From Law to Art to Medicine and beyond"),
        ("bell.badge.fill",   "Smart Reminders",            "Personalized schedule that keeps you on track"),
        ("chart.line.uptrend.xyaxis", "Deep Progress Insights", "See exactly how your vocabulary is growing"),
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            // Single ScrollView so the header + features can compress on small screens
            // and the user can always reach the product rows + purchase button.
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    header
                    featuresList
                    productRowsSection
                }
                .padding(.bottom, 120)  // leaves room for the pinned purchase button
            }

            // Pin the CTA to the bottom so it's always tappable, even mid-scroll
            VStack {
                Spacer()
                purchaseStickyFooter
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
            .frame(height: 180)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(AppSpacing.md)
            }

            VStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.accent)
                    .padding(.top, AppSpacing.lg)
                Text("Verbum Premium")
                    .font(.custom("Georgia-Bold", size: 26))
                    .foregroundColor(AppColors.textPrimary)
                Text("Learn without limits")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: - Features (compact one-line rows)

    private var featuresList: some View {
        VStack(spacing: 10) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(feature.title))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(LocalizedStringKey(feature.subtitle))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Product rows (scrollable inline)

    private var productRowsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            if subscriptions.isLoading {
                ProgressView().tint(AppColors.accent).padding()
            } else {
                productRows
                    .padding(.horizontal, AppSpacing.md)
            }
        }
    }

    // MARK: - Sticky purchase footer

    private var purchaseStickyFooter: some View {
        VStack(spacing: AppSpacing.xs) {
            purchaseButton
            if let error = subscriptions.purchaseError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
            footerLinks
                .padding(.top, 2)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(
            LinearGradient(
                colors: [AppColors.background.opacity(0), AppColors.background, AppColors.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 160)
            .offset(y: -20)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - CTA

    // MARK: - Product rows

    @State private var selectedProductID: String = SubscriptionManager.yearlyID

    @ViewBuilder
    private var productRows: some View {
        if subscriptions.products.isEmpty {
            // Never show hardcoded prices or a non-functional "buy" row — Apple rejects both.
            // Show an honest unavailable state with a retry instead.
            productsUnavailable
        } else {
            VStack(spacing: AppSpacing.xs) {
                if let monthly = subscriptions.monthlyProduct {
                    ProductRow(
                        product: monthly,
                        isSelected: selectedProductID == monthly.id,
                        badge: nil,
                        note: nil
                    ) { selectedProductID = monthly.id }
                }

                if let yearly = subscriptions.yearlyProduct {
                    ProductRow(
                        product: yearly,
                        isSelected: selectedProductID == yearly.id,
                        badge: "Best Value",
                        note: yearlyNote(yearly)
                    ) { selectedProductID = yearly.id }
                }

                if let lifetime = subscriptions.lifetimeProduct {
                    ProductRow(
                        product: lifetime,
                        isSelected: selectedProductID == lifetime.id,
                        badge: nil,
                        note: "One-time purchase"
                    ) { selectedProductID = lifetime.id }
                }
            }
        }
    }

    /// Localized "per-month · save X%" subtitle for the yearly plan, derived from the live
    /// StoreKit prices (never hardcoded — they vary by storefront/currency).
    private func yearlyNote(_ yearly: Product) -> String {
        let perMonth = (yearly.price / 12).formatted(yearly.priceFormatStyle)
        guard let monthly = subscriptions.monthlyProduct, monthly.price > 0 else {
            return "\(perMonth)/mo"
        }
        let perMonthValue = (yearly.price as NSDecimalNumber).doubleValue / 12.0
        let monthlyValue  = (monthly.price as NSDecimalNumber).doubleValue
        let pct = Int((1 - perMonthValue / monthlyValue) * 100)
        return pct > 0 ? "\(perMonth)/mo · Save \(pct)%" : "\(perMonth)/mo"
    }

    private var productsUnavailable: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Plans couldn’t be loaded")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text("Check your connection and try again.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                HapticManager.impact(.light)
                Task { await subscriptions.loadProducts() }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accent)
                    .cornerRadius(AppSpacing.cornerRadius)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
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
        if selectedProductID == SubscriptionManager.lifetimeID { return NSLocalizedString("Get Lifetime Access", comment: "paywall CTA") }
        return hasFreeTrial ? NSLocalizedString("Start Free Trial", comment: "paywall CTA") : NSLocalizedString("Subscribe Now", comment: "paywall CTA")
    }

    @ViewBuilder
    private var purchaseButton: some View {
        // No products → no purchase CTA (the unavailable/retry state stands in for it).
        if subscriptions.products.isEmpty {
            EmptyView()
        } else {
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
            .disabled(selectedProduct == nil)
            .opacity(selectedProduct == nil ? 0.5 : 1)
            .padding(.top, AppSpacing.sm)

            if selectedProductID != SubscriptionManager.lifetimeID {
                Text(LocalizedStringKey(hasFreeTrial
                     ? "Free trial, then auto-renews. Cancel anytime in Apple ID settings at least 24 hours before renewal."
                     : "Auto-renews. Cancel anytime in Apple ID settings at least 24 hours before renewal."))
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }
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

            Link("Privacy Policy", destination: AppInfo.privacyURL)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)

            Link("Terms of Use", destination: AppInfo.termsURL)
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

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)

                Text(period)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(AppColors.textPrimary)

                if let badge {
                    Text(LocalizedStringKey(badge))
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
                        Text(LocalizedStringKey(note))
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
