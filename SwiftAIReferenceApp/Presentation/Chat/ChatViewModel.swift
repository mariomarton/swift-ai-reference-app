import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    struct GenerationConflictPrompt: Equatable {
        let activeConversationID: UUID
    }

    private struct PendingSendRequest {
        let message: Message
        let model: LLMModel?
    }

    let conversationID: UUID

    @Published private(set) var messages: [Message] = []
    @Published var draftText = ""
    @Published var selectedModel: LLMModel?
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var streamingText: String?
    @Published var alert: PresentationAlert?
    @Published private(set) var generationConflictPrompt: GenerationConflictPrompt?

    private let loadRecentMessagesUseCase: LoadRecentMessagesUseCase
    private let generationCoordinator: any MessageGenerationCoordinating
    private var cancellables = Set<AnyCancellable>()
    private var lastHandledTerminalEventID: UUID?
    private var pendingSendRequest: PendingSendRequest?

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

    nonisolated deinit {
        cancellables.removeAll()
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
        let startResult = generationCoordinator.startGeneration(
            message: userMessage,
            to: conversationID,
            model: selectedModel
        )

        switch startResult {
        case .started:
            generationConflictPrompt = nil
            pendingSendRequest = nil
            messages.append(userMessage)
            draftText = ""
            applyGenerationState(generationCoordinator.state(for: conversationID))
        case .blocked(let activeConversationID):
            pendingSendRequest = PendingSendRequest(message: userMessage, model: selectedModel)
            generationConflictPrompt = GenerationConflictPrompt(activeConversationID: activeConversationID)
        }
    }

    func dismissGenerationConflictPrompt() {
        generationConflictPrompt = nil
        pendingSendRequest = nil
    }

    func stopGeneration() {
        generationConflictPrompt = nil
        pendingSendRequest = nil
        generationCoordinator.interruptGeneration(
            for: conversationID,
            errorDescription: L10n.Chat.userStoppedGenerationMessage
        )
    }

    func stopCurrentAndSendHere() {
        guard let pendingSendRequest else {
            generationConflictPrompt = nil
            return
        }

        let startResult = generationCoordinator.stopActiveGenerationAndStart(
            message: pendingSendRequest.message,
            to: conversationID,
            model: pendingSendRequest.model,
            interruptionErrorDescription: L10n.Chat.interruptedByNewConversationMessage
        )

        switch startResult {
        case .started:
            messages.append(pendingSendRequest.message)
            draftText = ""
            generationConflictPrompt = nil
            self.pendingSendRequest = nil
            applyGenerationState(generationCoordinator.state(for: conversationID))
        case .blocked(let activeConversationID):
            generationConflictPrompt = GenerationConflictPrompt(activeConversationID: activeConversationID)
        }
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
            if state.phase == .failed,
               state.errorDescription != L10n.Chat.userStoppedGenerationMessage {
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
