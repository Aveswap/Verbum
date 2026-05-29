import SwiftUI

/// Lists the user's custom word collections. Tapping a deck opens its words via WordListView.
/// Canonical implementation — themed with AppColors, swipe-to-delete via `List` (LazyVStack
/// would make `.onDelete` a no-op), and an empty-deck CTA that hops to Categories.
struct DecksView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showCreate = false
    @State private var newDeckName = ""
    @State private var selectedDeck: WordDeck?
    @State private var showCategories = false

    private var decks: [WordDeck] { userProfile.profile.decks }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                deckContent
            }
            .navigationTitle("My Decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { newDeckName = ""; showCreate = true } label: {
                        Image(systemName: "plus").foregroundColor(AppColors.accent)
                    }
                }
            }
            .alert("New Deck", isPresented: $showCreate) {
                TextField("Deck name", text: $newDeckName)
                Button("Create") {
                    let name = newDeckName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    userProfile.createDeck(name: name, icon: "books.vertical")
                    newDeckName = ""
                }
                Button("Cancel", role: .cancel) { newDeckName = "" }
            }
            .sheet(item: $selectedDeck) { deck in
                let words = WordRepository.shared.words(ids: deck.wordIds)
                WordListView(
                    title: deck.name,
                    words: words,
                    emptyIcon: "books.vertical",
                    emptyMessage: "This deck is empty. Browse categories to find words, then tap the stack icon on any word to add it here.",
                    onEmptyCTA: {
                        // Hop from the deck sheet to the categories sheet so the user can
                        // actually find words to add. Drop the deck sheet first to avoid
                        // SwiftUI dropping the chained presentation on iOS 16.
                        selectedDeck = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showCategories = true
                        }
                    }
                )
                .environmentObject(userProfile)
                .environmentObject(subscriptions)
            }
            .sheet(isPresented: $showCategories) {
                CategoriesView()
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var deckContent: some View {
        if decks.isEmpty {
            emptyState
        } else {
            // Must be a `List`: `.onDelete` is a no-op inside a `LazyVStack`.
            List {
                ForEach(decks) { deck in
                    Button {
                        selectedDeck = deck
                    } label: {
                        deckRow(deck)
                    }
                    .listRowBackground(AppColors.surface)
                }
                .onDelete { offsets in
                    offsets.forEach { i in userProfile.deleteDeck(decks[i].id) }
                }
            }
            .scrollContentBackground(.hidden)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
            PillButton(title: "Create First Deck") { newDeckName = ""; showCreate = true }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
