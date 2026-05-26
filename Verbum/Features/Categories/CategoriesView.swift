import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @EnvironmentObject var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showFavorites = false
    @State private var showHistory = false
    @State private var showPremium = false
    @State private var showWordList = false
    @State private var activeFilter: CategoryWordListView.FilterKind = .level(.beginner)

    struct CategoryBucket: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let dbCategories: [String]
        let premium: Bool
    }

    private let buckets: [CategoryBucket] = [
        CategoryBucket(name: "Daily Life",    icon: "house.fill",         dbCategories: ["Daily Life", "Food", "Social"],       premium: false),
        CategoryBucket(name: "Health & Body", icon: "heart.fill",         dbCategories: ["Health", "Sports"],                   premium: false),
        CategoryBucket(name: "Mind & Emotion",icon: "brain.head.profile", dbCategories: ["Emotion", "Communication"],           premium: false),
        CategoryBucket(name: "World & Nature",icon: "globe",              dbCategories: ["Travel", "Nature"],                   premium: false),
        CategoryBucket(name: "Tech & Science",icon: "cpu",                dbCategories: ["Technology", "Science"],              premium: true),
        CategoryBucket(name: "Work & Money",  icon: "briefcase.fill",     dbCategories: ["Business", "Finance"],                premium: true),
        CategoryBucket(name: "Arts & Ideas",  icon: "paintbrush.fill",    dbCategories: ["Art", "Academic"],                    premium: true),
        CategoryBucket(name: "Society & Law", icon: "building.columns.fill", dbCategories: ["Law"],                             premium: true),
    ]

    private let allWords = WordRepository.shared.all

    private func wordCount(for bucket: CategoryBucket) -> Int {
        allWords.filter { bucket.dbCategories.contains($0.category) }.count
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {

                        // Quick access
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                            QuickCard(title: "Favorites", icon: "heart.fill") { showFavorites = true }
                            QuickCard(title: "History",   icon: "clock.fill") { showHistory = true }
                        }

                        // 8 consolidated categories
                        CategorySection(title: "CATEGORIES") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                ForEach(buckets) { bucket in
                                    let count = wordCount(for: bucket)
                                    let locked = bucket.premium && !subscriptions.isPro
                                    if count > 0 {
                                        CategoryBucketCard(
                                            bucket: bucket,
                                            wordCount: count,
                                            isLocked: locked
                                        ) {
                                            if locked {
                                                showPremium = true
                                            } else {
                                                activeFilter = .categoryGroup(name: bucket.name, dbCategories: bucket.dbCategories)
                                                showWordList = true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // By Level filters
                        CategorySection(title: "BY LEVEL") {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(WordLevel.allCases, id: \.self) { level in
                                    SmallCard(title: level.displayName) {
                                        activeFilter = .level(level)
                                        showWordList = true
                                    }
                                }
                            }
                        }

                        // By Part of Speech
                        CategorySection(title: "BY PART OF SPEECH") {
                            let poses: [(String, String)] = [("Verbs","verb"),("Nouns","noun"),("Adjectives","adjective"),("Adverbs","adverb")]
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                                ForEach(poses, id: \.0) { name, pos in
                                    SmallCard(title: name) {
                                        activeFilter = .partOfSpeech(pos)
                                        showWordList = true
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
                        Button { searchText = "" } label: {
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
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                if !subscriptions.isPro {
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
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFavorites) { FavoritesView().environmentObject(userProfile) }
        .sheet(isPresented: $showHistory)   { HistoryView().environmentObject(userProfile) }
        .sheet(isPresented: $showPremium)   { PremiumSheet().environmentObject(subscriptions) }
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

private struct CategoryBucketCard: View {
    let bucket: CategoriesView.CategoryBucket
    let wordCount: Int
    let isLocked: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Image(systemName: bucket.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.accent)
                    Spacer()
                    Text(bucket.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isLocked ? AppColors.textSecondary : AppColors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(wordCount) words")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .frame(height: 100)
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
                .frame(minHeight: 44)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.surface)
                .cornerRadius(AppSpacing.cornerRadius)
        }
    }
}
