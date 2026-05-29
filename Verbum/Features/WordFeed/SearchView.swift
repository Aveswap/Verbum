import SwiftUI

/// Quick word lookup across the whole catalogue. Available from the feed top bar.
/// Results open WordDetailView, which applies the paywall gate (free users tapping a
/// locked word see the locked detail + premium upsell).
struct SearchView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Word] = []
    @State private var selectedWord: Word?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .sheet(item: $selectedWord) { word in
                WordDetailView(word: word)
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
            }
        }
        .preferredColorScheme(.dark)
        // Run the FTS read off the main actor; re-runs (and cancels) as the query changes.
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { results = []; return }
            let found = await Task.detached { WordRepository.shared.words(matching: q) }.value
            if !Task.isCancelled { results = found }
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
            TextField("Search words…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(AppColors.textPrimary)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    @ViewBuilder
    private var resultsList: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            placeholder(icon: "magnifyingglass", text: "Search the full dictionary by word, definition, or category.")
        } else if results.isEmpty {
            placeholder(icon: "questionmark.circle", text: "No words found for \"\(trimmed)\".")
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(results) { word in
                        Button { selectedWord = word } label: { resultRow(word) }
                    }
                }
                .padding(AppSpacing.md)
            }
        }
    }

    private func resultRow(_ word: Word) -> some View {
        let locked = !WordAccess.canAccess(word, isPro: subscriptions.isPro, userLevel: userProfile.profile.level)
        return HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.sm) {
                    Text(word.text)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(AppColors.textPrimary)
                    Text(word.partOfSpeech)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
                Text(word.definition)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(locked ? AppColors.accent : AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    private func placeholder(icon: String, text: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
