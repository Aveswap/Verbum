import SwiftUI

struct WordDetailView: View {
    let word: Word
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @StateObject private var viewModel: WordDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPremium = false
    @State private var showShare = false

    init(word: Word) {
        self.word = word
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(word: word))
    }

    private var isLocked: Bool {
        !WordAccess.canAccess(word, isPro: subscriptions.isPro, userLevel: userProfile.profile.level)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if isLocked {
                    lockedView
                } else {
                    detailScroll
                }
            }
            .navigationTitle(word.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(AppColors.accent)
                }
                if !isLocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: AppSpacing.sm) {
                            Button { showShare = true } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            if !userProfile.profile.decks.isEmpty {
                                Menu {
                                    ForEach(userProfile.profile.decks) { deck in
                                        Button {
                                            userProfile.toggleWord(word.id, in: deck.id)
                                        } label: {
                                            HStack {
                                                Text(deck.name)
                                                if deck.wordIds.contains(word.id) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "rectangle.stack.badge.plus")
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
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
            .sheet(isPresented: $showPremium) {
                PremiumSheet().environmentObject(subscriptions)
            }
            .sheet(isPresented: $showShare) {
                WordShareSheet(word: word, translation: nil)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var lockedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.accent)
            Text(word.text)
                .font(AppTypography.wordTitle)
                .foregroundColor(AppColors.textPrimary)
                .blur(radius: 6)
            Text("Premium word")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text("Unlock 1,000+ words across all difficulty levels.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            PillButton(title: "Get Premium") { showPremium = true }
                .padding(.horizontal, AppSpacing.lg)
            Button("Close") { dismiss() }
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, AppSpacing.xl)
        }
    }

    private var detailScroll: some View {
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

                        // Synonyms (Intermediate+)
                        if !word.synonyms.isEmpty && word.level != .beginner {
                            WordDetailSection(title: "Synonyms") {
                                FlowLayout(items: Array(word.synonyms.prefix(4))) { synonym in
                                    Text(synonym)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 4)
                                        .background(AppColors.surfaceSecondary)
                                        .cornerRadius(20)
                                }
                            }
                        }

                        // Collocations (Intermediate+)
                        if !word.collocations.isEmpty && word.level != .beginner {
                            WordDetailSection(title: "Common Phrases") {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(word.collocations, id: \.self) { col in
                                        Text("• \(col)")
                                            .font(.system(size: 15))
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                            }
                        }

                        // Antonyms (Expert only)
                        if !word.antonyms.isEmpty && word.level == .expert {
                            WordDetailSection(title: "Antonyms") {
                                FlowLayout(items: word.antonyms) { ant in
                                    Text(ant)
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textPrimary)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 4)
                                        .background(AppColors.surfaceSecondary)
                                        .cornerRadius(20)
                                }
                            }
                        }

                        // Etymology (Expert only)
                        if let etymology = word.etymology, word.level == .expert {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack(spacing: 6) {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(AppColors.accent)
                                    Text("Word History")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppColors.accent)
                                }
                                Text(etymology)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.accent.opacity(0.08))
                            .cornerRadius(AppSpacing.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                    .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                            )
                        }

                        // Category / level / meta row
                        HStack(spacing: AppSpacing.sm) {
                            Label(word.category, systemImage: "folder")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            if let reg = word.register {
                                Text(reg.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.surfaceSecondary)
                                    .cornerRadius(12)
                            }
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

                        // Domain tags (Expert only)
                        if !word.domainTags.isEmpty && word.level == .expert {
                            FlowLayout(items: word.domainTags) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.surfaceSecondary)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(AppSpacing.md)
                }
    }
}

private struct WordDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            content
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
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
