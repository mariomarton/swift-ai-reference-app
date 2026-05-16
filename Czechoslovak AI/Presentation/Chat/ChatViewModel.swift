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
    private let generationCoordinator: any MessageGenerationCoordinating
    private var cancellables = Set<AnyCancellable>()
    private var lastHandledTerminalEventID: UUID?

    init(
        conversationID: UUID,
        loadRecentMessagesUseCase: LoadRecentMessagesUseCase,
        generationCoordinator: any MessageGenerationCoordinating
    ) {
        self.conversationID = conversationID
        self.loadRecentMessagesUseCase = loadRecentMessagesUseCase
        self.generationCoordinator = generationCoordinator

        generationCoordinator.statesPublisher
            .sink { [weak self] states in
                self?.applyGenerationState(states[conversationID])
            }
            .store(in: &cancellables)

        applyGenerationState(generationCoordinator.state(for: conversationID))
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

        alert = nil

        let userMessage = Message(role: .user, text: trimmed)
        let didStart = generationCoordinator.startGeneration(
            message: userMessage,
            to: conversationID,
            model: selectedModel
        )

        guard didStart else { return }

        messages.append(userMessage)
        draftText = ""
        applyGenerationState(generationCoordinator.state(for: conversationID))
    }

    private func applyGenerationState(_ state: MessageGenerationCoordinator.ConversationState?) {
        guard let state else {
            isSending = false
            streamingText = nil
            return
        }

        switch state.phase {
        case .thinking:
            isSending = true
            streamingText = nil
        case .streaming:
            isSending = true
            streamingText = state.streamedText.isEmpty ? nil : state.streamedText
        case .completed:
            isSending = false
            streamingText = nil
            handleTerminalStateIfNeeded(state)
        case .failed:
            isSending = false
            streamingText = nil
            handleTerminalStateIfNeeded(state)
        }
    }

    private func handleTerminalStateIfNeeded(_ state: MessageGenerationCoordinator.ConversationState) {
        guard let terminalEventID = state.terminalEventID, terminalEventID != lastHandledTerminalEventID else {
            return
        }

        lastHandledTerminalEventID = terminalEventID

        Task {
            if state.phase == .failed {
                alert = PresentationAlert(
                    title: L10n.Chat.errorSendTitle,
                    message: state.errorDescription ?? L10n.Errors.unknown
                )
            }

            await refreshMessagesAfterGeneration()
            generationCoordinator.clearTerminalState(for: conversationID, matching: terminalEventID)
        }
    }

    private func refreshMessagesAfterGeneration() async {
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
