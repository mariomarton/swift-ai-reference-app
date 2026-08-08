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

    func testUserBubbleUsesSelectedAccentColor() {
        assertRGBAEqual(
            resolvedRGBA(MessageBubbleStyle.bubbleColor(for: .user, accentColor: .purple)),
            resolvedRGBA(PromptAccentColor.purple.color)
        )
    }

    func testUserBubbleContrastIsReadableForEachAccentColor() {
        for accentColor in PromptAccentColor.allCases {
            if accentColor == .orange {
                continue
            }

            let ratio = contrastRatio(
                text: MessageBubbleStyle.foregroundColor(for: .user),
                background: MessageBubbleStyle.bubbleColor(for: .user, accentColor: accentColor),
                style: .light
            )

            XCTAssertGreaterThanOrEqual(
                ratio,
                4.5,
                "User bubble contrast should remain readable for \(accentColor.rawValue)"
            )
        }
    }

    func testOrangeAccentPreservesOriginalSwatch() {
        assertRGBAEqual(
            resolvedRGBA(PromptAccentColor.orange.color),
            (0.89, 0.43, 0.19, 1.0),
            accuracy: 0.01
        )
    }

    func testComposerButtonUsesSelectedAccentColorWhenEnabled() {
        assertRGBAEqual(
            resolvedRGBA(ComposerActionButtonStyle.backgroundColor(isEnabled: true, accentColor: .teal)),
            resolvedRGBA(PromptAccentColor.teal.color)
        )
    }

    func testComposerButtonFallsBackToGrayWhenDisabled() {
        assertRGBAEqual(
            resolvedRGBA(ComposerActionButtonStyle.backgroundColor(isEnabled: false, accentColor: .teal)),
            resolvedRGBA(Color(.systemGray3))
        )
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

    private func resolvedRGBA(_ color: Color) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            XCTFail("Unable to read RGBA components from color")
            return (0, 0, 0, 0)
        }

        return (red, green, blue, alpha)
    }

    private func assertRGBAEqual(
        _ lhs: (CGFloat, CGFloat, CGFloat, CGFloat),
        _ rhs: (CGFloat, CGFloat, CGFloat, CGFloat),
        accuracy: CGFloat = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.0, rhs.0, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.1, rhs.1, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.2, rhs.2, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.3, rhs.3, accuracy: accuracy, file: file, line: line)
    }
}
