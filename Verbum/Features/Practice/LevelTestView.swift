import SwiftUI

struct LevelTestView: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LevelTestViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if vm.isFinished {
                    resultView
                        .transition(.opacity.combined(with: .scale))
                } else {
                    questionView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.isFinished)
            .navigationTitle("Level Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Question
    private var questionView: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

            Text("\(vm.currentIndex + 1) / \(vm.questions.count)")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 6)

            if let word = vm.currentQuestion {
                Spacer()
                Text(word.text)
                    .font(AppTypography.wordTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                Text(word.phonetic)
                    .font(AppTypography.phonetic)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
                Text("Choose the correct definition")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, AppSpacing.sm)
                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    ForEach(vm.options, id: \.self) { option in
                        Button { HapticManager.impact(.soft); vm.select(option) } label: {
                            optionRow(option, word: word)
                        }
                        .disabled(vm.selectedOption != nil)
                    }
                }
                .padding(.horizontal, AppSpacing.md)

                if vm.selectedOption != nil {
                    Button {
                        HapticManager.selection()
                        withAnimation { vm.next() }
                    } label: {
                        Text(vm.currentIndex < vm.questions.count - 1 ? "Next" : "See Result")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.accent)
                            .cornerRadius(AppSpacing.pillRadius)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.currentIndex)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(AppColors.surfaceSecondary).frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.accent)
                    .frame(width: geo.size.width * vm.progress, height: 6)
                    .animation(.easeOut, value: vm.currentIndex)
            }
        }
        .frame(height: 6)
    }

    private func optionRow(_ option: String, word: Word) -> some View {
        let selected = vm.selectedOption == option
        let correct = option == word.definition
        let revealed = vm.selectedOption != nil

        let bg: Color = {
            guard revealed else { return AppColors.surface }
            if correct { return AppColors.accent.opacity(0.25) }
            if selected { return Color.red.opacity(0.25) }
            return AppColors.surface
        }()
        let border: Color = {
            guard revealed else { return .clear }
            if correct { return AppColors.accent }
            if selected { return .red }
            return .clear
        }()

        return Text(option)
            .font(.system(size: 15))
            .foregroundColor(AppColors.textPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(bg)
            .cornerRadius(AppSpacing.cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius).stroke(border, lineWidth: 2))
            .animation(.easeOut(duration: 0.15), value: vm.selectedOption)
    }

    // MARK: - Result
    private var resultView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Text(resultEmoji)
                .font(.system(size: 72))
            Text("\(vm.score) / \(vm.questions.count)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            Text(vm.resultLevel.displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textOnAccent)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.accent)
                .cornerRadius(AppSpacing.pillRadius)
            Text(resultMessage)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            VStack(spacing: AppSpacing.sm) {
                Button {
                    HapticManager.success()
                    userProfile.profile.level = vm.resultLevel
                    dismiss()
                } label: {
                    Text("Set as My Level")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.accent)
                        .cornerRadius(AppSpacing.pillRadius)
                }
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var resultEmoji: String {
        switch vm.score {
        case 0...3: return "📘"
        case 4...7: return "📗"
        default: return "🏆"
        }
    }

    private var resultMessage: String {
        switch vm.score {
        case 0...3: return NSLocalizedString("You're building a strong foundation.\nKeep exploring new words every day!", comment: "level test result")
        case 4...7: return NSLocalizedString("Great command of vocabulary!\nYou're making excellent progress.", comment: "level test result")
        default: return NSLocalizedString("Outstanding performance!\nYou have an exceptional vocabulary.", comment: "level test result")
        }
    }
}
