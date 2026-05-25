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

            Text(title)
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

// MARK: - Promo Slide
struct PromoSlideView: View {
    let title: String
    let subtitle: String
    let icon: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(AppColors.accent)
            Text(title)
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            PillButton(title: buttonTitle, action: action)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}

// MARK: - Referral Source
struct ReferralSourceView: View {
    let onSkip: () -> Void
    let onSelect: (String) -> Void
    @State private var selected: String?

    private let options = ["TikTok", "Facebook", "App Store", "Friend/Family", "Web Search", "Instagram", "Other"]

    var body: some View {
        RadioSelectionView(title: "How did you hear\nabout us?", options: options, selected: selected, onSkip: onSkip) { opt in
            selected = opt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(opt) }
        }
    }
}

// MARK: - Age
struct AgeSelectionView: View {
    let onSkip: () -> Void
    let onSelect: (AgeRange) -> Void
    @State private var selected: AgeRange?

    var body: some View {
        RadioSelectionView(title: "How old are you?", options: AgeRange.allCases.map(\.rawValue), selected: selected?.rawValue, onSkip: onSkip) { val in
            if let age = AgeRange(rawValue: val) {
                selected = age
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(age) }
            }
        }
    }
}

// MARK: - Gender
struct GenderSelectionView: View {
    let onSkip: () -> Void
    let onSelect: (Gender) -> Void
    @State private var selected: Gender?

    var body: some View {
        RadioSelectionView(title: "What's your gender?", options: Gender.allCases.map(\.rawValue), selected: selected?.rawValue, onSkip: onSkip) { val in
            if let gender = Gender(rawValue: val) {
                selected = gender
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(gender) }
            }
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

// MARK: - Words Per Week
struct WordsPerWeekView: View {
    let onSelect: (Int) -> Void
    @State private var selected: Int?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("How many words\nper week?")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xl * 2)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                ForEach([10, 30, 50], id: \.self) { count in
                    RadioOptionRow(title: "\(count) words per week", isSelected: selected == count) {
                        selected = count
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(count) }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
    }
}

// MARK: - Level
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
    let onNext: () -> Void
    @State private var known: Set<String> = []

    private let words = ["ephemeral", "ubiquitous", "serendipity", "melancholy", "resilient",
                          "eloquent", "pragmatic", "ambiguous", "tenacious", "lucid",
                          "verbose", "candid", "astute", "benevolent", "discern"]

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Which words\ndo you know?")
                .font(AppTypography.heroTitle)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xl * 2)

            Text("Select all that apply")
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

            PillButton(title: "Next", action: onNext)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}
