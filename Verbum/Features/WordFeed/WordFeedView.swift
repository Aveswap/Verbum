import SwiftUI

struct WordFeedView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @StateObject private var viewModel = WordFeedViewModel()

    @State private var showDetail = false
    @State private var showProfile = false
    @State private var showPractice = false
    @State private var showCategories = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                wordArea
                actionRow
                bottomNav
            }
        }
        .sheet(isPresented: $showDetail) {
            if let word = viewModel.currentWord {
                WordDetailView(word: word).environmentObject(userProfile)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView().environmentObject(userProfile)
        }
        .sheet(isPresented: $showPractice) {
            PracticeMenuView()
        }
        .sheet(isPresented: $showCategories) {
            CategoriesView()
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button { showProfile = true } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }

            Spacer()

            WordProgressBar(
                current: min(userProfile.profile.bookmarkedWordIds.count, 5),
                total: 5
            )
            .frame(width: 130)

            Spacer()

            Button {} label: {
                Image(systemName: "crown.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Word Area
    private var wordArea: some View {
        Group {
            if let word = viewModel.currentWord {
                WordCardView(word: word, viewModel: viewModel)
                    .offset(y: dragOffset * 0.08)
                    .animation(.interactiveSpring(), value: dragOffset)
                    .gesture(swipeGesture)
                    .onTapGesture { showDetail = true }
                    .id(viewModel.currentIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.accent)
                    Text("Loading words…")
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, AppSpacing.sm)
                    Spacer()
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { val in
                let threshold: CGFloat = 50
                if val.translation.height < -threshold {
                    withAnimation(.easeInOut(duration: 0.25)) { viewModel.nextWord() }
                } else if val.translation.height > threshold {
                    withAnimation(.easeInOut(duration: 0.25)) { viewModel.previousWord() }
                }
                dragOffset = 0
            }
    }

    // MARK: - Action Row
    @ViewBuilder
    private var actionRow: some View {
        if let word = viewModel.currentWord {
            HStack(spacing: AppSpacing.xl) {
                Button { showDetail = true } label: {
                    Image(systemName: "info.circle")
                        .actionIcon()
                }
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                        .actionIcon()
                }
                Button { userProfile.likeWord(word.id) } label: {
                    Image(systemName: userProfile.profile.likedWordIds.contains(word.id) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(userProfile.profile.likedWordIds.contains(word.id) ? .red : AppColors.textSecondary)
                }
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                        userProfile.bookmarkWord(word.id)
                    }
                } label: {
                    Image(systemName: userProfile.profile.bookmarkedWordIds.contains(word.id) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 22))
                        .foregroundColor(userProfile.profile.bookmarkedWordIds.contains(word.id) ? AppColors.accent : AppColors.textSecondary)
                }
            }
            .padding(.vertical, AppSpacing.md)
        }
    }

    // MARK: - Bottom Nav
    private var bottomNav: some View {
        HStack {
            Spacer()
            BottomNavButton(icon: "square.grid.2x2", label: "Categories") { showCategories = true }
            Spacer()
            BottomNavButton(icon: "graduationcap", label: "Practice") { showPractice = true }
            Spacer()
            BottomNavButton(icon: "chart.bar", label: "Stats") {}
            Spacer()
        }
        .padding(.bottom, AppSpacing.lg)
    }
}

// MARK: - Word Card
private struct WordCardView: View {
    let word: Word
    let viewModel: WordFeedViewModel

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            if word.isNew {
                Text("NEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.accent)
                    .cornerRadius(8)
            }

            Text(word.text)
                .font(AppTypography.wordTitle)
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                Text(word.phonetic)
                    .font(AppTypography.phonetic)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.surface)
                    .cornerRadius(20)

                Button { viewModel.speakWord(word.text) } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Text("\(word.partOfSpeech)  \(word.definition)")
                .font(AppTypography.definition)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .lineLimit(3)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bottom Nav Button
private struct BottomNavButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.textSecondary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Helpers
private extension Image {
    func actionIcon() -> some View {
        self.font(.system(size: 22)).foregroundColor(AppColors.textSecondary)
    }
}
