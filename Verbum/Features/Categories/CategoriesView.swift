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
    @State private var activeFilter: CategoryWordListView.FilterKind = .search("")

    struct CategoryBucket: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let dbCategories: [String]
        let premium: Bool
    }

    // dbCategories must match the `category` column actually stored in words.json / words.db.
    // Current DB categories: Body, Character, Communication, Emotions, Food, General,
    // Literature, People, Psychology, Science, Society, Technology.
    private let buckets: [CategoryBucket] = [
        CategoryBucket(name: "Daily Life",     icon: "house.fill",            dbCategories: ["General", "Food", "People"],                premium: false),
        CategoryBucket(name: "Health & Body",  icon: "heart.fill",            dbCategories: ["Body"],                                     premium: false),
        CategoryBucket(name: "Mind & Emotion", icon: "brain.head.profile",    dbCategories: ["Emotions", "Psychology", "Communication"],  premium: false),
        CategoryBucket(name: "Character",      icon: "person.fill",           dbCategories: ["Character"],                                premium: false),
        CategoryBucket(name: "Tech & Science", icon: "cpu",                   dbCategories: ["Technology", "Science"],                    premium: true),
        CategoryBucket(name: "Arts & Ideas",   icon: "paintbrush.fill",       dbCategories: ["Literature"],                               premium: true),
        CategoryBucket(name: "Society",        icon: "building.columns.fill", dbCategories: ["Society"],                                  premium: true),
    ]

    private let allWords = WordRepository.shared.all

    /// Word count visible to *this* user inside the bucket — respects level + free-pool gating.
    /// Premium buckets still report their full count so the locked card shows "X words" while
    /// remaining tap-to-upgrade.
    private func wordCount(for bucket: CategoryBucket) -> Int {
        if bucket.premium {
            return allWords.filter { bucket.dbCategories.contains($0.category) }.count
        }
        let isPro = subscriptions.isPro
        return allWords.filter { word in
            bucket.dbCategories.contains(word.category) &&
            WordAccess.canAccess(word, isPro: isPro)
        }.count
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
            Text(LocalizedStringKey(title))
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
                Text(LocalizedStringKey(title)).font(.system(size: 14, weight: .medium)).foregroundColor(AppColors.textPrimary)
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
                    Text(LocalizedStringKey(bucket.name))
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
            Text(LocalizedStringKey(title))
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
