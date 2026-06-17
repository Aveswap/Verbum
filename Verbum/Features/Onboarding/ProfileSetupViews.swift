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

    /// Max chars accepted in the name field — protects layout + keychain payloads.
    private let nameMaxLength = 32

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func validate() -> String? {
        if trimmed.isEmpty { return NSLocalizedString("Please enter your name", comment: "name validation") }
        let lower = trimmed.lowercased()
        if blockedWords.contains(where: { lower.contains($0) }) { return NSLocalizedString("Please choose a different name", comment: "name validation") }
        return nil
    }

    /// Letters (any script), spaces, apostrophes and hyphens only — allows names like
    /// "O'Brien" / "Jean-Luc" while blocking digits, emoji, symbols and punctuation.
    private func sanitize(_ raw: String) -> String {
        let allowed = raw.unicodeScalars.filter {
            CharacterSet.letters.contains($0)
            || $0 == " " || $0 == "'" || $0 == "\u{2019}" || $0 == "-"
        }
        var cleaned = String(String.UnicodeScalarView(allowed))
        if cleaned.count > nameMaxLength {
            cleaned = String(cleaned.prefix(nameMaxLength))
        }
        return cleaned
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
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .onAppear { isFocused = true }
                    .onChange(of: name) { newValue in
                        let cleaned = sanitize(newValue)
                        if cleaned != newValue { name = cleaned }
                        errorMessage = nil
                    }

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
