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
        rendered.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            guard value == nil else { return }
            rendered.addAttribute(.font, value: bodyFont, range: range)
        }

        return rendered
    }
    #endif
}
