import SwiftUI

// MARK: - Shared Radio Selection Screen
struct RadioSelectionView: View {
    let title: String
    let options: [String]
    let selected: String?
    var onSkip: (() -> Void)?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack {
                Spacer()
                if let onSkip {
                    Button("Skip", action: onSkip)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.trailing, AppSpacing.md)
                }
            }
            .padding(.top, AppSpacing.md)

            Text(LocalizedStringKey(title))
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    RadioOptionRow(title: option, isSelected: selected == option) {
                        onSelect(option)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
    }
}

// MARK: - Name
struct NameInputView: View {
    let onNext: (String) -> Void
    @State private var name = ""
    @State private var errorMessage: String? = nil
    @FocusState private var isFocused: Bool

    private let blockedWords: Set<String> = [
        "fuck", "shit", "ass", "bitch", "bastard", "dick", "cock", "pussy",
        "cunt", "whore", "slut", "nigger", "nigga", "faggot", "retard",
        "блядь", "сука", "хуй", "пизда", "єбать", "їбать", "мудак", "підарас"
    ]

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func validate() -> String? {
        if trimmed.isEmpty { return "Please enter your name" }
        let lower = trimmed.lowercased()
        if blockedWords.contains(where: { lower.contains($0) }) { return "Please choose a different name" }
        return nil
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("What's your name?")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xl * 2)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Your name", text: $name)
                    .font(AppTypography.optionLabel)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onChange(of: name) { _ in errorMessage = nil }

                if let msg = errorMessage {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            PillButton(title: "Next") {
                if let err = validate() {
                    errorMessage = err
                    HapticManager.error()
                } else {
                    onNext(trimmed)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}

struct LevelSelectionView: View {
    let onSelect: (WordLevel) -> Void
    @State private var selected: WordLevel?

    var body: some View {
        RadioSelectionView(title: "What's your vocabulary\nlevel?", options: WordLevel.allCases.map(\.displayName), selected: selected?.displayName, onSkip: nil) { val in
            if let level = WordLevel.allCases.first(where: { $0.displayName == val }) {
                selected = level
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(level) }
            }
        }
    }
}

// MARK: - Word Check
struct WordCheckView: View {
    // knownCount: how many of the 15 test words the user recognised
    let onNext: (_ knownCount: Int) -> Void
    @State private var known: Set<String> = []

    // 5 Beginner, 5 Intermediate, 5 Expert words — position signals difficulty
    private let words = ["resilient", "candid", "lucid", "vivid", "serene",
                         "eloquent", "pragmatic", "ambiguous", "tenacious", "verbose",
                         "ephemeral", "ubiquitous", "serendipity", "melancholy", "discern"]

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Which words\ndo you know?")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xl * 2)

            Text("Tap all the words you recognise")
                .foregroundColor(AppColors.textSecondary)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                    ForEach(words, id: \.self) { word in
                        Button {
                            if known.contains(word) { known.remove(word) } else { known.insert(word) }
                        } label: {
                            Text(word)
                                .font(.system(size: 15))
                                .foregroundColor(known.contains(word) ? AppColors.textOnAccent : AppColors.textPrimary)
                                .padding(.vertical, AppSpacing.sm)
                                .frame(maxWidth: .infinity)
                                .background(known.contains(word) ? AppColors.accent : AppColors.surface)
                                .cornerRadius(AppSpacing.cornerRadius)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            PillButton(title: "Next") { onNext(known.count) }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}
