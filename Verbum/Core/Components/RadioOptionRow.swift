import SwiftUI

struct RadioOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppTypography.optionLabel)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 13, height: 13)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? AppColors.surfaceSecondary : AppColors.surface)
            .cornerRadius(AppSpacing.cornerRadius)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
