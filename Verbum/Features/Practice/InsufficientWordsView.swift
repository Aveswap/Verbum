import SwiftUI

/// Shown when the user hasn't seen enough words to play a practice game.
/// Practice games filter from `seenWordIds` so the user reinforces what they've learned, not random words.
struct InsufficientWordsView: View {
    let needed: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "book.closed.fill")
                .font(.system(size: 70))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
            Text("Learn first, then practice")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Swipe through at least \(needed) words in the feed, then come back to practice them.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            PillButton(title: "Back to Feed", action: onDismiss)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}
