import SwiftUI

// MARK: - Color Scheme Preference

enum AppColorScheme: String, CaseIterable {
    case light, dark, auto

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        case .auto:  return nil
        }
    }

    var systemIcon: String {
        switch self {
        case .light: return "sun.max"
        case .dark:  return "moon"
        case .auto:  return "circle.lefthalf.filled"
        }
    }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        case .auto:  return "Auto"
        }
    }
}

// MARK: - Theme

struct AppTheme {
    // Colors — defined in Assets.xcassets with Light/Dark variants
    static let background     = Color("AppBackground")
    static let primaryText    = Color("AppPrimaryText")
    static let mutedText      = Color("AppMutedText")
    static let completedText  = Color("AppCompletedText")
    static let accent         = Color("AppAccent")
    static let paperLine      = Color("AppPaperLine")
    static let checkboxBorder = Color("AppCheckboxBorder")

    // Typography
    static let headlineFont: Font = .system(size: 22, weight: .light, design: .serif)
    static let bodyFont:     Font = .system(size: 15, weight: .regular, design: .serif)
    static let captionFont:  Font = .system(size: 10, weight: .regular)
    static let monoFont:     Font = .system(size: 9, weight: .semibold, design: .monospaced)

    // Layout
    static let rowPaddingH: CGFloat = 22
    static let rowPaddingV: CGFloat = 11
}
