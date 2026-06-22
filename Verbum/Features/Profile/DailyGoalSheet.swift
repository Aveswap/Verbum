import SwiftUI

/// Slider sheet for editing the daily learning goal. Presented from the Profile hub
/// (the app settings were merged into ProfileView).
struct DailyGoalSheet: View {
    @State private var value: Double
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    init(initial: Int, onSave: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
        _value = State(initialValue: Double(initial))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: AppSpacing.xl) {
                    Spacer()
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.accent)
                    Text("\(Int(value))")
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: value)
                    Text("words per day")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                    Slider(value: $value, in: 1...30, step: 1)
                        .tint(AppColors.accent)
                        .padding(.horizontal, AppSpacing.lg)
                    HStack {
                        Text("Casual")
                        Spacer()
                        Text("Serious")
                        Spacer()
                        Text("Intense")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.lg)
                    Spacer()
                    PillButton(title: "Save") { onSave(Int(value)) }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                }
            }
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onCancel() } label: {
                        Image(systemName: "xmark").foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
