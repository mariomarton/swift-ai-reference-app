import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

protocol AssistantMarkdownRendering {
    func renderSwiftUIAttributedText(markdown: String) -> AttributedString
    #if canImport(UIKit)
    func renderUIKitAttributedText(markdown: String, textColor: UIColor) -> NSAttributedString
    #endif
}

struct AssistantMarkdownRenderer: AssistantMarkdownRendering {
    func renderSwiftUIAttributedText(markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let rendered = try? AttributedString(markdown: markdown, options: options) {
            return rendered
        }

        return AttributedString(markdown)
    }

    #if canImport(UIKit)
    func renderUIKitAttributedText(markdown: String, textColor: UIColor) -> NSAttributedString {
        let swiftUIAttributedText = renderSwiftUIAttributedText(markdown: markdown)
        let rendered = NSMutableAttributedString(swiftUIAttributedText)
        let fullRange = NSRange(location: 0, length: rendered.length)

        rendered.addAttribute(.foregroundColor, value: textColor, range: fullRange)

        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        var location = 0

        for run in swiftUIAttributedText.runs {
            let runTextLength = String(swiftUIAttributedText[run.range].characters).utf16.count
            guard runTextLength > 0 else { continue }

            let runRange = NSRange(location: location, length: runTextLength)
            rendered.addAttribute(.font, value: font(for: run, bodyFont: bodyFont), range: runRange)
            location += runTextLength
        }

        return rendered
    }

    private func font(for run: AttributedString.Runs.Run, bodyFont: UIFont) -> UIFont {
        guard let inlineIntent = run.inlinePresentationIntent else {
            return bodyFont
        }

        if inlineIntent.contains(.code) {
            let weight: UIFont.Weight = inlineIntent.contains(.stronglyEmphasized) ? .semibold : .regular
            return UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: weight)
        }

        var additionalTraits = UIFontDescriptor.SymbolicTraits()
        if inlineIntent.contains(.stronglyEmphasized) {
            additionalTraits.insert(.traitBold)
        }
        if inlineIntent.contains(.emphasized) {
            additionalTraits.insert(.traitItalic)
        }

        guard !additionalTraits.isEmpty else {
            return bodyFont
        }

        let combinedTraits = bodyFont.fontDescriptor.symbolicTraits.union(additionalTraits)
        guard let descriptor = bodyFont.fontDescriptor.withSymbolicTraits(combinedTraits) else {
            return bodyFont
        }

        return UIFont(descriptor: descriptor, size: bodyFont.pointSize)
    }
    #endif
}
