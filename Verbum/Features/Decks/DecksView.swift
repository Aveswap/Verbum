import SwiftUI

/// Lists the user's custom word collections. Tapping a deck opens its words via WordListView.
struct DecksView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var showNewDeck = false
    @State private var newDeckName = ""
    @State private var openDeck: WordDeck?

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if userProfile.profile.decks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(userProfile.profile.decks) { deck in
                                Button { openDeck = deck } label: { deckRow(deck) }
                            }
                            .onDelete(perform: deleteDecks)
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .navigationTitle("My Decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewDeck = true } label: {
                        Image(systemName: "plus").foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("New Deck", isPresented: $showNewDeck) {
            TextField("Deck name", text: $newDeckName)
            Button("Create") {
                let trimmed = newDeckName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    userProfile.createDeck(name: trimmed)
                    newDeckName = ""
                }
            }
            Button("Cancel", role: .cancel) { newDeckName = "" }
        }
        .sheet(item: $openDeck) { deck in
            let words = WordRepository.shared.words(ids: deck.wordIds)
            WordListView(
                title: deck.name,
                words: words,
                emptyIcon: "books.vertical",
                emptyMessage: "This deck is empty. Add words from any word's detail screen."
            )
            .environmentObject(userProfile)
        }
    }

    private func deckRow(_ deck: WordDeck) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: deck.icon)
                .font(.system(size: 22))
                .foregroundColor(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.accent.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(deck.wordIds.count) words")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.cornerRadius)
    }

    private func deleteDecks(at offsets: IndexSet) {
        let ids = offsets.map { userProfile.profile.decks[$0].id }
        ids.forEach { userProfile.deleteDeck($0) }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
            Text("No decks yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text("Group words into custom collections to study what matters to you.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            PillButton(title: "Create First Deck") { showNewDeck = true }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
        }
    }
}
