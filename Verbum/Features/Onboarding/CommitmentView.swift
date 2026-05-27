import SwiftUI

/// Commitment device shown after level + word-check. Projects how many words the user will
/// know in 30 days at their daily pace — anchors them to a measurable, motivating goal.
struct CommitmentView: View {
    let level: WordLevel
    let dailyGoal: Int
    let onContinue: () -> Void

    private var projection30: Int { dailyGoal * 30 }
    private var projection7: Int { dailyGoal * 7 }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.xs) {
                Text("In 30 days, you'll know")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textSecondary)

                Text("+\(projection30)")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accent)
                    .contentTransition(.numericText())

                Text("new words")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textSecondary)
            }

            // Mini bar chart: 4 weekly bars showing growth
            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                ForEach(1...4, id: \.self) { week in
                    VStack(spacing: 4) {
                        Text("+\(projection7 * week)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.accent.opacity(0.35 + 0.18 * Double(week)))
                            .frame(width: 36, height: CGFloat(week) * 22)
                        Text("W\(week)")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.top, AppSpacing.md)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                    Text("\(dailyGoal) words a day")
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColors.textPrimary)
                Text("Less than 2 minutes a day. You can change this anytime in Settings.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            .padding(.top, AppSpacing.sm)

            Spacer()

            PillButton(title: "I'm in") { onContinue() }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
        }
    }
}
