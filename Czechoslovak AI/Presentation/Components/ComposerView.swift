import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    let isSending: Bool
    let onPrimaryAction: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(L10n.Composer.placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .accessibilityIdentifier("messageTextField")

            Button(action: onPrimaryAction) {
                Image(systemName: isSending ? "stop.fill" : "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(canUsePrimaryAction ? Color(red: 0.89, green: 0.43, blue: 0.19) : Color(.systemGray3))
                    )
            }
            .disabled(!canUsePrimaryAction)
            .accessibilityLabel(isSending ? L10n.Composer.stopAccessibilityLabel : L10n.Composer.sendAccessibilityLabel)
            .accessibilityIdentifier("sendMessageButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }

    private var canUsePrimaryAction: Bool {
        if isSending {
            return true
        }

        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}