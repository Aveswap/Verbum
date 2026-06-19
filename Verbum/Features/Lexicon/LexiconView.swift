import SwiftUI

/// The personal lexicon — the words the user has "claimed" (bookmarked), each with their own
/// "why this word is mine" note. This is the ownership artifact: a growing self-portrait the user
/// returns to, not a feed they consume. (Council verdict: retention comes from what you've *made*.)
struct LexiconView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var editingWord: Word?
    @State private var shareWord: Word?

    /// Claimed words, most-recently-claimed first, resolved against the live catalogue.
    private var claimedWords: [Word] {
        let byId = Dictionary(WordRepository.shared.all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return userProfile.profile.bookmarkedWordIds.reversed().compactMap { byId[$0] }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if claimedWords.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(claimedWords) { row($0) }
                        }
                        .padding(AppSpacing.lg)
                    }
                }
            }
            .navigationTitle("My Lexicon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .sheet(item: $editingWord) { LexiconNoteSheet(word: $0).environmentObject(userProfile) }
            .sheet(item: $shareWord) { WordShareSheet(word: $0) }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ word: Word) -> some View {
        let note = userProfile.note(for: word.id)
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(word.text)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button {
                    Analytics.log(.cardShared, ["from": "lexicon"])
                    shareWord = word
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel("Send \(word.text) to a friend")
            }
            Text(word.definition)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
            if note.isEmpty {
                Label("Add why it's yours", systemImage: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .padding(.top, 2)
            } else {
                Text("\u{201C}\(note)\u{201D}")
                    .font(.system(size: 14).italic())
                    .foregroundColor(AppColors.textPrimary.opacity(0.85))
                    .padding(.top, 2)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
        .contentShape(Rectangle())
        .onTapGesture { editingWord = word }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundColor(AppColors.accent.opacity(0.7))
            Text("Your lexicon is empty")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            Text("Tap the bookmark on a word that moves you —\nit becomes yours here, with your own note.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }
}

/// Lightweight sheet to capture/edit the user's personal note for a claimed word. Optional and
/// skippable — pressure would defeat the point; the note is a gift to your future self, not a task.
struct LexiconNoteSheet: View {
    let word: Word
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(word.text)
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Why is this word yours?")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("A memory, a moment, where you'd use it…")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary.opacity(0.6))
                                .padding(.top, 8).padding(.leading, 5)
                        }
                        TextEditor(text: $text)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface)
                    .cornerRadius(AppSpacing.cornerRadius)
                    Spacer()
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle("Your note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") { dismiss() }.foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        userProfile.setNote(trimmed, for: word.id)
                        if !trimmed.isEmpty { Analytics.log(.noteAdded) }
                        HapticManager.success()
                        dismiss()
                    }.foregroundColor(AppColors.accent)
                }
            }
            .onAppear { text = userProfile.note(for: word.id) }
        }
        .preferredColorScheme(.dark)
    }
}
