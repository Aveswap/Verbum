import SwiftUI

struct DecksView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var showCreate = false
    @State private var newDeckName = ""
    @State private var selectedDeck: WordDeck?

    private var decks: [WordDeck] { userProfile.profile.decks }

    var body: some View {
        NavigationStack {
            deckContent
                .navigationTitle("My Decks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { newDeckName = ""; showCreate = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .alert("New Deck", isPresented: $showCreate) {
                    TextField("Deck name", text: $newDeckName)
                    Button("Create") {
                        let name = newDeckName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        userProfile.createDeck(name: name, icon: "books.vertical")
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .sheet(item: $selectedDeck) { deck in
                    let words = WordRepository.shared.words(ids: deck.wordIds)
                    WordListView(
                        title: deck.name,
                        words: words,
                        emptyIcon: "books.vertical",
                        emptyMessage: "No words in this deck yet."
                    )
                    .environmentObject(userProfile)
                    .environmentObject(subscriptions)
                }
        }
    }

    @ViewBuilder
    private var deckContent: some View {
        if decks.isEmpty {
            emptyState
        } else {
            List {
                ForEach(decks) { deck in
                    Button {
                        selectedDeck = deck
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: deck.icon)
                                .frame(width: 32)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(deck.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(deck.wordIds.count) words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.forEach { i in userProfile.deleteDeck(decks[i].id) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No decks yet")
                .font(.title3.weight(.semibold))
            Text("Create a deck to organise your favourite words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
