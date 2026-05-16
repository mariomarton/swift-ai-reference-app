import Combine
import Foundation

protocol MessageGenerationCoordinating: AnyObject {
    var statesPublisher: AnyPublisher<[UUID: MessageGenerationCoordinator.ConversationState], Never> { get }

    func state(for conversationID: UUID) -> MessageGenerationCoordinator.ConversationState?

    @discardableResult
    func startGeneration(message: Message, to conversationID: UUID, model: LLMModel?) -> Bool

    func clearTerminalState(for conversationID: UUID, matching terminalEventID: UUID?)
}

@MainActor
final class MessageGenerationCoordinator: ObservableObject, MessageGenerationCoordinating {
    struct ConversationState: Equatable {
        enum Phase: Equatable {
            case thinking
            case streaming
            case completed
            case failed
        }

        let phase: Phase
        let streamedText: String
        let errorDescription: String?
        let terminalEventID: UUID?

        var isInProgress: Bool {
            switch phase {
            case .thinking, .streaming:
                return true
            case .completed, .failed:
                return false
            }
        }
    }

    @Published private(set) var states: [UUID: ConversationState] = [:]

    var statesPublisher: AnyPublisher<[UUID: ConversationState], Never> {
        $states.eraseToAnyPublisher()
    }

    private let sendMessageUseCase: SendMessageUseCase
    private let updateInterval: Duration
    private var tasks: [UUID: Task<Void, Never>] = [:]

    init(
        sendMessageUseCase: SendMessageUseCase,
        updateInterval: Duration = .milliseconds(50)
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.updateInterval = updateInterval
    }

    func state(for conversationID: UUID) -> ConversationState? {
        states[conversationID]
    }

    private func updateStates(_ mutation: (inout [UUID: ConversationState]) -> Void) {
        var updatedStates = states
        mutation(&updatedStates)
        states = updatedStates
    }

    @discardableResult
    func startGeneration(message: Message, to conversationID: UUID, model: LLMModel?) -> Bool {
        guard tasks[conversationID] == nil, !(states[conversationID]?.isInProgress ?? false) else {
            return false
        }

        updateStates { states in
            states[conversationID] = ConversationState(
                phase: .thinking,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: nil
            )
        }

        let sendMessageUseCase = self.sendMessageUseCase
        let updateInterval = self.updateInterval
        let stream = sendMessageUseCase.send(message: message, to: conversationID, model: model)

        tasks[conversationID] = Task.detached(priority: .userInitiated) { [weak self] in
            let clock = ContinuousClock()

            var bufferedText = ""
            var lastFlush = clock.now

            func flushBuffer(force: Bool = false) async {
                guard !bufferedText.isEmpty else { return }
                guard force || lastFlush.duration(to: clock.now) >= updateInterval else { return }

                let flushed = bufferedText
                bufferedText = ""
                lastFlush = clock.now
                await self?.appendStreamedText(flushed, to: conversationID)
            }

            do {
                for try await token in stream {
                    bufferedText += token
                    await flushBuffer()
                }

                await flushBuffer(force: true)
                await self?.markCompleted(for: conversationID)
            } catch {
                await flushBuffer(force: true)
                await self?.markFailed(for: conversationID, errorDescription: error.localizedDescription)
            }
        }

        return true
    }

    func clearTerminalState(for conversationID: UUID, matching terminalEventID: UUID? = nil) {
        guard let state = states[conversationID], !state.isInProgress else { return }

        if let terminalEventID, state.terminalEventID != terminalEventID {
            return
        }

        updateStates { states in
            states.removeValue(forKey: conversationID)
        }
    }

    private func appendStreamedText(_ text: String, to conversationID: UUID) {
        guard !text.isEmpty else { return }

        let existing = states[conversationID]
        let combinedText = (existing?.streamedText ?? "") + text
        updateStates { states in
            states[conversationID] = ConversationState(
                phase: .streaming,
                streamedText: combinedText,
                errorDescription: nil,
                terminalEventID: nil
            )
        }
    }

    private func markCompleted(for conversationID: UUID) {
        tasks[conversationID] = nil
        updateStates { states in
            states[conversationID] = ConversationState(
                phase: .completed,
                streamedText: "",
                errorDescription: nil,
                terminalEventID: UUID()
            )
        }
    }

    private func markFailed(for conversationID: UUID, errorDescription: String) {
        tasks[conversationID] = nil
        let existing = states[conversationID]
        updateStates { states in
            states[conversationID] = ConversationState(
                phase: .failed,
                streamedText: existing?.streamedText ?? "",
                errorDescription: errorDescription,
                terminalEventID: UUID()
            )
        }
    }
}
