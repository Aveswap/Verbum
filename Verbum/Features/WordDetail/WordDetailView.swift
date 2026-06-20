import SwiftUI

struct WordDetailView: View {
    let word: Word
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @StateObject private var viewModel: WordDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPremium = false
    @State private var showShare = false
    /// Cross-user like count (nil unless the backend is enabled).
    @State private var otherLikes: Int?
    // Main reading text scales with Dynamic Type (base size at default, grows for large text).
    @ScaledMetric(relativeTo: .largeTitle) private var wordTitleSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var definitionSize: CGFloat = 18

    init(word: Word) {
        self.word = word
        _viewModel = StateObject(wrappedValue: WordDetailViewModel(word: word))
    }

    private var isLocked: Bool {
        !WordAccess.canAccess(word, isPro: subscriptions.isPro)
    }

    var body: some View {
        content
            .task { otherLikes = await PublicLikes.service.likeCount(wordID: word.id) }
    }

    private var content: some View {
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
                            .accessibilityLabel("Share word")
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
                                .accessibilityLabel("Add to deck")
                            }
                            Button { userProfile.likeWord(word.id) } label: {
                                Image(systemName: userProfile.profile.likedWordIds.contains(word.id) ? "heart.fill" : "heart")
                                    .foregroundColor(userProfile.profile.likedWordIds.contains(word.id) ? .red : AppColors.textSecondary)
                            }
                            .accessibilityLabel(userProfile.profile.likedWordIds.contains(word.id) ? "Unlike word" : "Like word")
                            Button { userProfile.bookmarkWord(word.id) } label: {
                                Image(systemName: userProfile.profile.bookmarkedWordIds.contains(word.id) ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(AppColors.accent)
                            }
                            .accessibilityLabel(userProfile.profile.bookmarkedWordIds.contains(word.id) ? "Remove bookmark" : "Bookmark word")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPremium) {
                PremiumSheet().environmentObject(subscriptions)
            }
            .sheet(isPresented: $showShare) {
                WordShareSheet(word: word)
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
            Text("Unlock the full collection of rare, beautiful words.")
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
                                .font(.system(size: wordTitleSize, weight: .bold, design: .serif))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)

                            HStack {
                                // Phonetic is optional — languages without an IPA transcription
                                // (e.g. Ukrainian) leave it blank; omit the empty pill entirely.
                                if !word.phonetic.isEmpty {
                                    Text(word.phonetic)
                                        .font(AppTypography.phonetic)
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.horizontal, AppSpacing.sm)
                                        .padding(.vertical, 4)
                                        .background(AppColors.surface)
                                        .cornerRadius(20)
                                }

                                Button { viewModel.speakWord() } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(AppColors.accent)
                                        .font(.system(size: 18))
                                }
                                .accessibilityLabel("Pronounce \(word.text)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.md)

                        // Definition card
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(word.localizedPartOfSpeech)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                            Text(word.definition)
                                .font(.system(size: definitionSize, weight: .regular))
                                .foregroundColor(AppColors.textPrimary)
                            // Cross-user likes — shown only when the backend is enabled & returns a count.
                            if let likes = otherLikes, likes > 0 {
                                Label("\(likes) \(likes == 1 ? "person" : "people") loved this", systemImage: "heart.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.pink)
                            }
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

                        // Synonyms (shown when present)
                        if !word.synonyms.isEmpty {
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

                        // Collocations (shown when present)
                        if !word.collocations.isEmpty {
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

                        // Antonyms (shown when present)
                        if !word.antonyms.isEmpty {
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

                        // Etymology (shown when present)
                        if let etymology = word.etymology {
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
                            Label(word.localizedCategory, systemImage: "folder")
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
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.cornerRadius)

                        // Domain tags (shown when present)
                        if !word.domainTags.isEmpty {
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
                // The word title uses a large fixed design font; cap Dynamic Type so the largest
                // accessibility sizes scale up readably without shattering the card layouts.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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
        // True wrap layout: each chip is sized to fit its content (no fixed-width column),
        // then placed left-to-right with rows wrapping as needed. Using LazyVGrid here
        // forced columns at a minimum width and clipped/wrapped longer chips like
        // "comprehend" so the last letter dropped to a new line.
        WrapFlow(spacing: AppSpacing.sm, lineSpacing: 6) {
            ForEach(items, id: \.self, content: content)
        }
    }
}

/// Lightweight flow container (iOS 16+ Layout). Lays out subviews at their natural width,
/// wrapping to a new line when the row's running width exceeds the container.
struct WrapFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height + lineSpacing } - (rows.isEmpty ? 0 : lineSpacing)
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.size
                item.view.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct RowItem { let view: LayoutSubview; let size: CGSize }
    private struct Row { var items: [RowItem] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let projected = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if projected > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            let added = current.items.isEmpty ? size.width : current.width + spacing + size.width
            current.items.append(RowItem(view: sub, size: size))
            current.width = added
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
