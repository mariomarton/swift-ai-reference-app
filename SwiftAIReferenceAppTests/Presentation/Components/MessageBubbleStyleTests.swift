import XCTest
import SwiftUI
import UIKit
@testable import SwiftAIReferenceApp

@MainActor
final class MessageBubbleStyleTests: XCTestCase {
    func testAssistantBubbleContrastIsReadableInDarkMode() {
        let ratio = contrastRatio(
            text: MessageBubbleStyle.foregroundColor(for: .assistant),
            background: MessageBubbleStyle.bubbleColor(for: .assistant),
            style: .dark
        )

        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Assistant bubble contrast in dark mode should be readable")
    }

    func testAssistantBubbleContrastIsReadableInLightMode() {
        let ratio = contrastRatio(
            text: MessageBubbleStyle.foregroundColor(for: .assistant),
            background: MessageBubbleStyle.bubbleColor(for: .assistant),
            style: .light
        )

        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Assistant bubble contrast in light mode should be readable")
    }

    func testSystemBubbleContrastIsReadableInDarkMode() {
        let ratio = contrastRatio(
            text: MessageBubbleStyle.foregroundColor(for: .system),
            background: MessageBubbleStyle.bubbleColor(for: .system),
            style: .dark
        )

        XCTAssertGreaterThanOrEqual(ratio, 4.5, "System bubble contrast in dark mode should be readable")
    }

    private func contrastRatio(text: Color, background: Color, style: UIUserInterfaceStyle) -> Double {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let textColor = UIColor(text).resolvedColor(with: trait)
        let backgroundColor = UIColor(background).resolvedColor(with: trait)

        let textLuminance = relativeLuminance(for: textColor)
        let backgroundLuminance = relativeLuminance(for: backgroundColor)

        let lighter = max(textLuminance, backgroundLuminance)
        let darker = min(textLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(for color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            XCTFail("Unable to read RGBA components from color")
            return 0
        }

        let linearRed = linearized(Double(red))
        let linearGreen = linearized(Double(green))
        let linearBlue = linearized(Double(blue))

        return 0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue
    }

    private func linearized(_ channel: Double) -> Double {
        if channel <= 0.03928 {
            return channel / 12.92
        }
        return pow((channel + 0.055) / 1.055, 2.4)
    }
}
