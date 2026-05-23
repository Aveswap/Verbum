import SwiftUI

struct PracticeMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showQuiz = false

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // Level test card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("What's your level?")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Take the free test")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.accent)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.cornerRadius)

                        // Challenges
                        sectionHeader("CHALLENGES")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(["Perfection", "Rush", "Sprint"], id: \.self) { name in
                                    ChallengeCard(title: name, isLocked: true)
                                }
                            }
                        }

                        // Practice games
                        sectionHeader("PRACTICE")
                        PracticeRow(title: "Word Meaning", subtitle: "Choose the correct definition", icon: "questionmark.circle") {
                            showQuiz = true
                        }
                        PracticeRow(title: "Fill the Gap", subtitle: "Complete the sentence", icon: "text.cursor") {}
                        PracticeRow(title: "Find Synonyms", subtitle: "Match similar words", icon: "arrow.left.arrow.right") {}
                        PracticeRow(title: "Guess the Word", subtitle: "From definition to word", icon: "lightbulb") {}
                        PracticeRow(title: "Word Definition", subtitle: "Pick the right meaning", icon: "book") {}
                    }
                    .padding(AppSpacing.md)
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Unlock All") {}
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textOnAccent)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 5)
                        .background(AppColors.accent)
                        .cornerRadius(20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showQuiz) {
            QuizView()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
    }
}

private struct ChallengeCard: View {
    let title: String
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(width: 120, height: 100)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.locked)
                    .padding(6)
            }
        }
    }
}

private struct PracticeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 13))
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
        }
    }
}
