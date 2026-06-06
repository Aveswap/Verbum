import SwiftUI

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
        if trimmed.isEmpty { return NSLocalizedString("Please enter your name", comment: "name validation") }
        let lower = trimmed.lowercased()
        if blockedWords.contains(where: { lower.contains($0) }) { return NSLocalizedString("Please choose a different name", comment: "name validation") }
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
