import SwiftUI

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

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            VStack(alignment: bubbleAlignment, spacing: 6) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(MessageBubbleStyle.foregroundColor(for: message.role))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MessageBubbleStyle.bubbleColor(for: message.role), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

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

}