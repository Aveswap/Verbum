import SwiftUI

/// Reusable word list used by Favorites, History, and Category detail screens.
struct WordListView: View {
    let title: String
    let words: [Word]
    let emptyIcon: String
    let emptyMessage: String
    /// Optional override for the empty-state CTA. When nil, the CTA falls back
    /// to dismissing the sheet (parent decides what "browse" means).
    var onEmptyCTA: (() -> Void)? = nil

    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWord: Word?
    @State private var searchText = ""

    private var filtered: [Word] {
        guard !searchText.isEmpty else { return words }
        return words.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            $0.definition.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if words.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(filtered) { word in
                                WordRow(word: word)
                                    .onTapGesture { selectedWord = word }
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                    .searchable(text: $searchText, prompt: "Search words…")
                }
            }
            .navigationTitle(LocalizedStringKey(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(words.count) words")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedWord) { word in
            WordDetailView(word: word).environmentObject(userProfile)
        }
    }

    private var emptyCTALabel: String {
        if title.lowercased().contains("history") { return "Start Swiping" }
        return "Browse Categories"
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: emptyIcon)
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
            Text(LocalizedStringKey(emptyMessage))
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button { onEmptyCTA?() ?? dismiss() } label: {
                Text(LocalizedStringKey(emptyCTALabel))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accentButton)
                    .clipShape(Capsule())
            }
            .padding(.top, AppSpacing.sm)
        }
    }
}

struct WordRow: View {
    let word: Word
    @EnvironmentObject var userProfile: UserProfileStore

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.sm) {
                    Text(word.text)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(AppColors.textPrimary)
                    Text(word.localizedPartOfSpeech)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accent.opacity(0.15))
                        .cornerRadius(6)
                }
                Text(word.phonetic)
                    .font(AppTypography.phonetic)
                    .foregroundColor(AppColors.textSecondary)
                Text(word.definition)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                MasteryDots(level: userProfile.mastery(for: word.id))
            }
            Spacer()
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: userProfile.profile.bookmarkedWordIds.contains(word.id) ? "bookmark.fill" : "bookmark")
                    .foregroundColor(userProfile.profile.bookmarkedWordIds.contains(word.id) ? AppColors.accent : AppColors.textSecondary)
                    .font(.system(size: 16))
                    .onTapGesture {
                        HapticManager.impact(.soft)
                        userProfile.bookmarkWord(word.id)
                    }
                LevelBadge(level: word.level)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}

private struct MasteryDots: View {
    let level: Int  // 0...5
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < level ? AppColors.accent : AppColors.surfaceSecondary)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

private struct LevelBadge: View {
    let level: WordLevel
    private var color: Color {
        switch level {
        case .beginner:     return .green
        case .intermediate: return .orange
        case .expert:       return .red
        }
    }
    var body: some View {
        Text(level.displayName.prefix(3).uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}
