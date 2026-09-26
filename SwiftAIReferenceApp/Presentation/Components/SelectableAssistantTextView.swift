import SwiftUI
#if canImport(UIKit)
import UIKit

struct SelectableAssistantTextView: UIViewRepresentable {
    let attributedText: NSAttributedString

    static func makeConfiguredTextView() -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.widthTracksTextView = true
        view.adjustsFontForContentSizeCategory = true
        view.font = .preferredFont(forTextStyle: .body)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func makeUIView(context: Context) -> UITextView {
        Self.makeConfiguredTextView()
    }

    static func applyContent(attributedText: NSAttributedString, to view: UITextView) {
        guard !view.attributedText.isEqual(to: attributedText) else { return }

        let preservedSelection = view.selectedRange
        view.attributedText = attributedText
        view.selectedRange = clampedSelection(preservedSelection, textLength: attributedText.length)
    }

    private static func clampedSelection(_ selection: NSRange, textLength: Int) -> NSRange {
        guard selection.location != NSNotFound else {
            return selection
        }

        let clampedLocation = min(max(selection.location, 0), textLength)
        let maxLength = max(0, textLength - clampedLocation)
        let clampedLength = min(max(selection.length, 0), maxLength)

        return NSRange(location: clampedLocation, length: clampedLength)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        Self.applyContent(attributedText: attributedText, to: uiView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else {
            return uiView.sizeThatFits(CGSize(width: UIView.noIntrinsicMetric, height: .greatestFiniteMagnitude))
        }

        let fittingSize = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: fittingSize.height)
    }
}
#endif
