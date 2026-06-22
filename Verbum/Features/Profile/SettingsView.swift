import SwiftUI
import UIKit

// Settings were merged into ProfileView (the single top-left hub). This file now only holds the
// shared sub-sheets that hub presents.

// MARK: - Word Language

/// Localized display name for a vocabulary language code (BCP-47 base).
func wordLanguageDisplayName(_ code: String) -> String {
    switch code {
    case "en": return "English"
    case "uk": return "Українська"
    case "de": return "Deutsch"
    case "it": return "Italiano"
    case "fr": return "Français"
    default:   return Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
}

struct WordLanguagePickerSheet: View {
    let available: [String]
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                List {
                    ForEach(available, id: \.self) { code in
                        Button {
                            onSelect(code)
                        } label: {
                            HStack {
                                Text(wordLanguageDisplayName(code))
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selected == code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
            .navigationTitle("Word Language")
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
}

// MARK: - Daily Goal Sheet

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
