import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum MessageBubbleStyle {
    static func bubbleColor(for role: Message.Role) -> Color {
        switch role {
        case .user:
            return Color(red: 0.89, green: 0.43, blue: 0.19)
        case .assistant:
            return Color(.secondarySystemBackground)
        case .system:
            return Color(.tertiarySystemBackground)
        }
    }

    static func foregroundColor(for role: Message.Role) -> Color {
        role == .user ? .white : .primary
    }
}

struct MessageBubbleInteractionPolicy {
    let enablesTextSelection: Bool
    let showsCopyContextMenu: Bool

    static func forRole(_ role: Message.Role) -> MessageBubbleInteractionPolicy {
        switch role {
        case .user:
            return MessageBubbleInteractionPolicy(enablesTextSelection: false, showsCopyContextMenu: true)
        case .assistant:
            return MessageBubbleInteractionPolicy(enablesTextSelection: true, showsCopyContextMenu: false)
        case .system:
            return MessageBubbleInteractionPolicy(enablesTextSelection: false, showsCopyContextMenu: false)
        }
    }
}

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            VStack(alignment: bubbleAlignment, spacing: 6) {
                interactiveBubbleText

                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)

            if message.role != .user {
                Spacer(minLength: 48)
            }
        }
    }

    private var bubbleAlignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var interactionPolicy: MessageBubbleInteractionPolicy {
        MessageBubbleInteractionPolicy.forRole(message.role)
    }

    private var plainBubbleText: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(MessageBubbleStyle.foregroundColor(for: message.role))
    }

    @ViewBuilder
    private var assistantSelectableText: some View {
        #if canImport(UIKit)
        SelectableAssistantTextView(
            text: message.text,
            textColor: UIColor(MessageBubbleStyle.foregroundColor(for: .assistant))
        )
        #else
        plainBubbleText
            .textSelection(.enabled)
        #endif
    }

    private func bubbleTextContent<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(MessageBubbleStyle.bubbleColor(for: message.role), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var interactiveBubbleText: some View {
        if interactionPolicy.showsCopyContextMenu {
            bubbleTextContent {
                plainBubbleText
            }
                .contextMenu {
                    Button(L10n.MessageActions.copy) {
                        copyMessageTextToPasteboard()
                    }
                }
        } else if interactionPolicy.enablesTextSelection {
            bubbleTextContent {
                assistantSelectableText
            }
        } else {
            bubbleTextContent {
                plainBubbleText
            }
        }
    }

    private func copyMessageTextToPasteboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = message.text
        #endif
    }

}