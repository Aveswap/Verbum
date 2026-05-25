import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showFavorites = false
    @State private var showHistory = false
    @State private var showPremium = false
    @State private var showWordList = false
    @State private var activeFilter: CategoryWordListView.FilterKind = .category("People")

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // Quick access 2x2
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                            QuickCard(title: "Favorites", icon: "heart.fill") { showFavorites = true }
                            QuickCard(title: "Collections", icon: "folder.fill") { showPremium = true }
                            QuickCard(title: "My Words", icon: "plus.circle.fill") { showPremium = true }
                            QuickCard(title: "History", icon: "clock.fill") { showHistory = true }
                        }

                        CategorySection(title: "EVERYDAY LIFE") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.sm) {
                                    ForEach(["People", "Body", "Food & Drink", "Emotions", "Society", "Character"], id: \.self) { cat in
                                        HScrollCard(title: cat) {
                                            activeFilter = .category(cat)
                                            showWordList = true
                                        }
                                    }
                                }
                            }
                        }

                        CategorySection(title: "PROFESSIONAL") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                ForEach(["Technology", "Science", "Medicine", "Literature", "Psychology"], id: \.self) { cat in
                                    LockedCard(title: cat, isLocked: true) { showPremium = true }
                                }
                            }
                        }

                        CategorySection(title: "BY PART OF SPEECH") {
                            let posMap: [String: String] = ["Verbs": "verb", "Nouns": "noun", "Adjectives": "adjective", "Adverbs": "adverb"]
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                ForEach(["Verbs", "Nouns", "Adjectives", "Adverbs"], id: \.self) { cat in
                                    SmallCard(title: cat) {
                                        activeFilter = .partOfSpeech(posMap[cat] ?? cat.lowercased())
                                        showWordList = true
                                    }
                                }
                            }
                        }

                        CategorySection(title: "BY LEVEL") {
                            let levelMap: [String: WordLevel] = ["Beginner": .beginner, "Intermediate": .intermediate, "Expert": .expert]
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                ForEach(["Beginner", "Intermediate", "Expert"], id: \.self) { cat in
                                    SmallCard(title: cat) {
                                        if let level = levelMap[cat] {
                                            activeFilter = .level(level)
                                            showWordList = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .padding(.bottom, 80)
                }

                // Search bar pinned at bottom
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                    TextField("Search words…", text: $searchText)
                        .foregroundColor(AppColors.textPrimary)
                        .submitLabel(.search)
                        .onSubmit {
                            let q = searchText.trimmingCharacters(in: .whitespaces)
                            guard !q.isEmpty else { return }
                            activeFilter = .search(q)
                            showWordList = true
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(AppSpacing.cornerRadius)
                .padding(AppSpacing.md)
            }
            .navigationTitle("Explore Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Unlock All") { showPremium = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.accent)
                        .cornerRadius(20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFavorites) { FavoritesView().environmentObject(userProfile) }
        .sheet(isPresented: $showHistory)   { HistoryView().environmentObject(userProfile) }
        .sheet(isPresented: $showPremium)   { PremiumSheet() }
        .sheet(isPresented: $showWordList)  { CategoryWordListView(filter: activeFilter).environmentObject(userProfile) }
    }
}

private struct CategorySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            content
        }
    }
}

private struct QuickCard: View {
    let title: String
    let icon: String
    var action: (() -> Void)? = nil
    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Image(systemName: icon).foregroundColor(AppColors.accent)
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }
}

private struct HScrollCard: View {
    let title: String
    var action: (() -> Void)? = nil
    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.accent)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(width: 100, height: 85)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }
}

private struct LockedCard: View {
    let title: String
    let isLocked: Bool
    var onTap: (() -> Void)? = nil
    var body: some View {
        Button(action: { onTap?() }) {
            ZStack(alignment: .topTrailing) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(AppColors.surface)
                    .cornerRadius(AppSpacing.cornerRadius)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.locked)
                        .padding(6)
                }
            }
        }
    }
}

private struct SmallCard: View {
    let title: String
    var action: (() -> Void)? = nil
    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.cornerRadius)
        }
    }
}
