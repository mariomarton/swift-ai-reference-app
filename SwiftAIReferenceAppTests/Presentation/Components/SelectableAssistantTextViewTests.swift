import XCTest
import UIKit
@testable import SwiftAIReferenceApp

@MainActor
final class SelectableAssistantTextViewTests: XCTestCase {
    func testConfiguredTextViewIsSelectableAndNotEditable() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()

        XCTAssertTrue(view.isSelectable)
        XCTAssertFalse(view.isEditable)
        XCTAssertFalse(view.isScrollEnabled)
    }

    func testConfiguredTextViewUsesBubbleFriendlyLayoutDefaults() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()

        XCTAssertEqual(view.textContainerInset, .zero)
        XCTAssertEqual(view.textContainer.lineFragmentPadding, 0)
        XCTAssertTrue(view.textContainer.widthTracksTextView)
        XCTAssertEqual(view.backgroundColor, .clear)
    }

    func testConfiguredTextViewSupportsDynamicTypeBodyFont() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()

        XCTAssertTrue(view.adjustsFontForContentSizeCategory)
        XCTAssertEqual(view.font?.textStyle, .body)
    }

    func testApplyContentPreservesSelectionWhenTextIsUnchanged() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()
        let attributedText = NSAttributedString(string: "Bratislava je hlavne mesto Slovenska.")
        view.attributedText = attributedText
        view.textColor = .label
        view.selectedRange = NSRange(location: 5, length: 10)

        SelectableAssistantTextView.applyContent(
            attributedText: attributedText,
            to: view
        )

        XCTAssertEqual(view.selectedRange.location, 5)
        XCTAssertEqual(view.selectedRange.length, 10)
    }

    func testApplyContentUpdatesTextWhenDifferent() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()
        view.attributedText = NSAttributedString(string: "Stary text")
        let updatedText = NSAttributedString(string: "Novy text")

        SelectableAssistantTextView.applyContent(
            attributedText: updatedText,
            to: view
        )

        XCTAssertEqual(view.attributedText.string, "Novy text")
    }

    func testApplyContentUpdatesAttributesWhenVisibleTextIsUnchanged() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()
        let originalText = "Ahoj svet"
        view.attributedText = NSAttributedString(string: originalText)
        view.selectedRange = NSRange(location: 2, length: 4)

        let updatedText = NSMutableAttributedString(string: originalText)
        updatedText.addAttribute(
            .font,
            value: UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize),
            range: NSRange(location: 5, length: 4)
        )

        SelectableAssistantTextView.applyContent(
            attributedText: updatedText,
            to: view
        )

        XCTAssertEqual(view.selectedRange.location, 2)
        XCTAssertEqual(view.selectedRange.length, 4)

        let boldFont = view.attributedText.attribute(.font, at: 6, effectiveRange: nil) as? UIFont
        XCTAssertNotNil(boldFont)
        XCTAssertTrue(boldFont?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    func testApplyContentClampsSelectionWhenUpdatedTextIsShorter() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()
        view.attributedText = NSAttributedString(string: "Dlhsi text")
        view.selectedRange = NSRange(location: 7, length: 3)

        SelectableAssistantTextView.applyContent(
            attributedText: NSAttributedString(string: "Kratky"),
            to: view
        )

        XCTAssertEqual(view.selectedRange.location, 6)
        XCTAssertEqual(view.selectedRange.length, 0)
    }
}

private extension UIFont {
    var textStyle: TextStyle? {
        guard let style = fontDescriptor.fontAttributes[.textStyle] as? TextStyle else {
            return nil
        }
        return style
    }
}
