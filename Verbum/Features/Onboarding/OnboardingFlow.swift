import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, name, nativeLanguage, level, wordCheck
}

struct OnboardingFlow: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @State private var currentStep: OnboardingStep = .welcome

    private var stepProgress: Double {
        let total = Double(OnboardingStep.allCases.count - 1)
        return Double(currentStep.rawValue) / total
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar (hidden on welcome screen)
                if currentStep != .welcome {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(AppColors.surface).frame(height: 3)
                            Rectangle()
                                .fill(AppColors.accent)
                                .frame(width: geo.size.width * stepProgress, height: 3)
                                .animation(.easeInOut(duration: 0.4), value: stepProgress)
                        }
                    }
                    .frame(height: 3)
                }

                stepView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .id(currentStep)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case .welcome:
            WelcomeView { advance() }
        case .name:
            NameInputView { name in
                userProfile.profile.name = name; advance()
            }
        case .nativeLanguage:
            NativeLanguageView(onSkip: { advance() }, onSelect: { lang in
                userProfile.profile.nativeLanguage = lang; advance()
            })
        case .level:
            LevelSelectionView { level in
                userProfile.profile.level = level; advance()
            }
        case .wordCheck:
            WordCheckView { knownCount in
                if knownCount >= 10 {
                    userProfile.profile.level = .expert
                } else if knownCount >= 5 {
                    userProfile.profile.level = .intermediate
                } else {
                    userProfile.profile.level = .beginner
                }
                advance()
            }
        }
    }

    private func advance() {
        HapticManager.selection()
        let steps = OnboardingStep.allCases
        guard let idx = steps.firstIndex(of: currentStep), idx + 1 < steps.count else {
            userProfile.profile.onboardingCompleted = true
            return
        }
        currentStep = steps[idx + 1]
    }
}
