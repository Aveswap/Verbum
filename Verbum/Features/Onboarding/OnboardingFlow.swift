import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, referralSource, personalizationPromo, age, gender, name,
         customizePromo, wordsPerWeek, widgetsPromo, notifications,
         goalsPromo, level, wordCheck, theme
}

struct OnboardingFlow: View {
    @EnvironmentObject var userProfile: UserProfileStore
    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            stepView
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .id(currentStep)
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case .welcome:
            WelcomeView { advance() }
        case .referralSource:
            ReferralSourceView(onSkip: { advance() }, onSelect: { _ in advance() })
        case .personalizationPromo:
            PromoSlideView(
                title: "We're personalizing\nyour word recommendations",
                subtitle: "Based on your preferences, we'll suggest words you'll love",
                icon: "wand.and.stars",
                buttonTitle: "Great!",
                action: { advance() }
            )
        case .age:
            AgeSelectionView(onSkip: { advance() }, onSelect: { age in
                userProfile.profile.age = age; advance()
            })
        case .gender:
            GenderSelectionView(onSkip: { advance() }, onSelect: { gender in
                userProfile.profile.gender = gender; advance()
            })
        case .name:
            NameInputView { name in
                userProfile.profile.name = name; advance()
            }
        case .customizePromo:
            PromoSlideView(
                title: "Customize the app\nfor yourself",
                subtitle: "Set your goals and we'll help you achieve them",
                icon: "slider.horizontal.3",
                buttonTitle: "Next",
                action: { advance() }
            )
        case .wordsPerWeek:
            WordsPerWeekView { count in
                userProfile.profile.wordsPerWeek = count; advance()
            }
        case .widgetsPromo:
            PromoSlideView(
                title: "Choose from\nseveral widgets",
                subtitle: "Add Verbum widgets to your home screen for daily learning",
                icon: "rectangle.grid.2x2",
                buttonTitle: "Next",
                action: { advance() }
            )
        case .notifications:
            NotificationsSetupView { advance() }
        case .goalsPromo:
            PromoSlideView(
                title: "Bookmark words to\nachieve your goals",
                subtitle: "Save 5 words to start receiving personalized recommendations",
                icon: "bookmark.fill",
                buttonTitle: "Next",
                action: { advance() }
            )
        case .level:
            LevelSelectionView { level in
                userProfile.profile.level = level; advance()
            }
        case .wordCheck:
            WordCheckView { advance() }
        case .theme:
            ThemeSelectionView { theme in
                userProfile.profile.selectedTheme = theme
                userProfile.profile.onboardingCompleted = true
            }
        }
    }

    private func advance() {
        let steps = OnboardingStep.allCases
        guard let idx = steps.firstIndex(of: currentStep), idx + 1 < steps.count else { return }
        currentStep = steps[idx + 1]
    }
}
