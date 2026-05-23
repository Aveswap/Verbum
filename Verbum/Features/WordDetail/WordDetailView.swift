import SwiftUI

struct WordDetailView: View {
    let word: Word
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel: WordDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(word: Word) {
        self.word = word
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(word: word))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        // Word header
                        VStack(spacing: AppSpacing.sm) {
                            Text(word.text)
                                .font(AppTypography.wordTitle)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)

                            HStack {
                                Text(word.phonetic)
                                    .font(AppTypography.phonetic)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 4)
                                    .background(AppColors.surface)
                                    .cornerRadius(20)

                                Button { viewModel.speakWord() } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(AppColors.accent)
                                        .font(.system(size: 18))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.md)

                        // Definition card
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(word.partOfSpeech)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                            Text(word.definition)
                                .font(AppTypography.definition)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.cornerRadius)

                        // Example
                        if let example = word.exampleSentence {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Example")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                Text(example)
                                    .font(.system(size: 16).italic())
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.surface)
                            .cornerRadius(AppSpacing.cornerRadius)
                        }

                        // Synonyms
                        if !word.synonyms.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Synonyms")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                FlowLayout(items: word.synonyms) { synonym in
                                    Text(synonym)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 4)
                                        .background(AppColors.surfaceSecondary)
                                        .cornerRadius(20)
                                }
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.surface)
                            .cornerRadius(AppSpacing.cornerRadius)
                        }

                        // Category badge
                        HStack {
                            Label(word.category, systemImage: "folder")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text(word.level.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textOnAccent)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 4)
                                .background(AppColors.accent)
                                .cornerRadius(20)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle(word.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppSpacing.sm) {
                        Button { userProfile.likeWord(word.id) } label: {
                            Image(systemName: userProfile.profile.likedWordIds.contains(word.id) ? "heart.fill" : "heart")
                                .foregroundColor(userProfile.profile.likedWordIds.contains(word.id) ? .red : AppColors.textSecondary)
                        }
                        Button { userProfile.bookmarkWord(word.id) } label: {
                            Image(systemName: userProfile.profile.bookmarkedWordIds.contains(word.id) ? "bookmark.fill" : "bookmark")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), alignment: .leading)], alignment: .leading) {
            ForEach(items, id: \.self, content: content)
        }
    }
}
