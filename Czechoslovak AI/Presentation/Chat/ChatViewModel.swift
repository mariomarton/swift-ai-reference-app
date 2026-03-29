import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    let conversationID: UUID

    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published var selectedModel: LLMModel?
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var streamingText: String?
    @Published var alert: PresentationAlert?

    private let loadRecentMessagesUseCase: LoadRecentMessagesUseCase
    private let sendMessageUseCase: SendMessageUseCase

    init(
        conversationID: UUID,
        loadRecentMessagesUseCase: LoadRecentMessagesUseCase,
        sendMessageUseCase: SendMessageUseCase
    ) {
        self.conversationID = conversationID
        self.loadRecentMessagesUseCase = loadRecentMessagesUseCase
        self.sendMessageUseCase = sendMessageUseCase
    }

    func loadMessages(limit: Int? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        alert = nil
        defer { isLoading = false }

        do {
            messages = try await loadRecentMessagesUseCase.loadRecentMessages(for: conversationID, limit: limit)
        } catch {
            alert = PresentationAlert(
                title: L10n.Chat.errorLoadTitle,
                message: error.localizedDescription,
                isRetryable: true
            )
        }
    }

    func sendMessage() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        isSending = true
        alert = nil
        defer {
            isSending = false
            streamingText = nil
        }

        let userMessage = Message(role: .user, text: trimmed)
        let stream = sendMessageUseCase.send(message: userMessage, to: conversationID, model: selectedModel)
        draftText = ""
        streamingText = ""

        do {
            for try await token in stream {
                streamingText = (streamingText ?? "") + token
            }
        } catch {
            alert = PresentationAlert(
                title: L10n.Chat.errorSendTitle,
                message: error.localizedDescription
            )
            // Best-effort refresh — user message may have been persisted before the failure
            do {
                messages = try await loadRecentMessagesUseCase.loadRecentMessages(for: conversationID, limit: nil)
            } catch { /* ignore secondary error */ }
            return
        }

        do {
            messages = try await loadRecentMessagesUseCase.loadRecentMessages(for: conversationID, limit: nil)
        } catch {
            alert = PresentationAlert(
                title: L10n.Chat.errorRefreshTitle,
                message: error.localizedDescription,
                isRetryable: true
            )
        }
    }
}
