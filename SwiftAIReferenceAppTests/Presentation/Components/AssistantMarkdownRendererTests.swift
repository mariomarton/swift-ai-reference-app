import XCTest
import SwiftUI
import UIKit
@testable import SwiftAIReferenceApp

@MainActor
final class AssistantMarkdownRendererTests: XCTestCase {
    private let renderer = AssistantMarkdownRenderer()

    func testSwiftUIRenderingRemovesMarkdownSyntaxFromVisibleText() {
        let rendered = renderer.renderSwiftUIAttributedText(markdown: "Ahoj **svet**")

        XCTAssertEqual(String(rendered.characters), "Ahoj svet")
    }

    func testSwiftUIRenderingPreservesNewlinesAndWhitespace() {
        let rendered = renderer.renderSwiftUIAttributedText(
            markdown: "Top cities:\n\n- **Zurich**\n- **Prague**\n\nCulture: **Barcelona**"
        )

        XCTAssertEqual(
            String(rendered.characters),
            "Top cities:\n\n- Zurich\n- Prague\n\nCulture: Barcelona"
        )
    }

    func testSwiftUIRenderingPreservesLinkAttributes() {
        let rendered = renderer.renderSwiftUIAttributedText(markdown: "[GitHub](https://github.com)")

        let hasLink = rendered.runs.contains { run in
            run.link == URL(string: "https://github.com")
        }

        XCTAssertTrue(hasLink)
    }

    func testUIKitRenderingUsesResolvedPlainText() {
        let rendered = renderer.renderUIKitAttributedText(
            markdown: "Toto je **dolezite**",
            textColor: .label
        )

        XCTAssertEqual(rendered.string, "Toto je dolezite")
    }

    func testUIKitRenderingMapsStrongMarkdownToBoldFontTrait() {
        let rendered = renderer.renderUIKitAttributedText(
            markdown: "Toto je **dolezite**",
            textColor: .label
        )

        let text = rendered.string as NSString
        let boldRange = text.range(of: "dolezite")

        XCTAssertNotEqual(boldRange.location, NSNotFound)

        let font = rendered.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    func testUIKitRenderingPreservesWhitespaceAroundFormattedText() {
        let rendered = renderer.renderUIKitAttributedText(
            markdown: "Cities:\n- **Zurich**\n- **Vienna**",
            textColor: .label
        )

        XCTAssertEqual(rendered.string, "Cities:\n- Zurich\n- Vienna")
    }

    func testUIKitRenderingAppliesRequestedTextColor() {
        let rendered = renderer.renderUIKitAttributedText(markdown: "Obsah", textColor: .systemTeal)
        let fullRange = NSRange(location: 0, length: rendered.length)
        var allRangesUseRequestedColor = true

        rendered.enumerateAttribute(.foregroundColor, in: fullRange) { value, _, stop in
            guard let color = value as? UIColor, color == .systemTeal else {
                allRangesUseRequestedColor = false
                stop.pointee = true
                return
            }
        }

        XCTAssertTrue(allRangesUseRequestedColor)
    }
}
