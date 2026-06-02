import SwiftUI

struct PillButton: View {
    let title: String
    let action: () -> Void
    var isFullWidth: Bool = true

    var body: some View {
        Button(action: action) {
            // LocalizedStringKey so literal titles ("Done", "Next", …) localize; a non-key
            // string just falls back to itself.
            Text(LocalizedStringKey(title))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textOnAccent)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, AppSpacing.md)
                .padding(.horizontal, AppSpacing.xl)
                .background(AppColors.accentButton)
                .clipShape(Capsule())
        }
    }
}
