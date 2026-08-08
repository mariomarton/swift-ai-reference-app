import SwiftUI

extension PromptAccentColor {
    var color: Color {
        switch self {
        case .orange:
            return Color(red: 0.89, green: 0.43, blue: 0.19)
        case .blue:
            return Color(red: 0.16, green: 0.32, blue: 0.80)
        case .indigo:
            return Color(red: 0.31, green: 0.27, blue: 0.80)
        case .purple:
            return Color(red: 0.45, green: 0.21, blue: 0.72)
        case .teal:
            return Color(red: 0.00, green: 0.48, blue: 0.50)
        case .green:
            return Color(red: 0.13, green: 0.43, blue: 0.20)
        case .red:
            return Color(red: 0.70, green: 0.18, blue: 0.21)
        }
    }
}
