import Combine
import Foundation
import SwiftUI

protocol MessageGenerationCoordinating: AnyObject {
    var statesPublisher: AnyPublisher<[UUID: MessageGenerationCoordinator.ConversationState], Never> { get }

    func state(for conversationID: UUID) -> MessageGenerationCoordinator.ConversationState?

    @discardableResult
    func startGeneration(message: Message, to conversationID: UUID, model: LLMModel?) -> Bool

    func interruptGeneration(for conversationID: UUID, errorDescription: String)
    func handleScenePhaseChange(_ newPhase: ScenePhase)

    func clearTerminalState(for conversationID: UUID, matching terminalEventID: UUID?)
}

@MainActor
final class MessageGenerationCoordinator: ObservableObject, MessageGenerationCoordinating, ConversationGenerationStateObserving {
    private struct TaskRecord {
        let generationID: UUID
        let task: Task<Void, Never>
    }

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
    private let backgroundTaskManager: any BackgroundTaskManaging
    private let updateInterval: Duration
    private var tasks: [UUID: TaskRecord] = [:]
    private var scenePhase: ScenePhase = .active
    private var activeBackgroundTaskConversationIDs: Set<UUID> = []

    init(
        sendMessageUseCase: SendMessageUseCase,
        backgroundTaskManager: (any BackgroundTaskManaging)? = nil,
        updateInterval: Duration = .milliseconds(50)
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.backgroundTaskManager = backgroundTaskManager ?? UIKitBackgroundTaskManager()
        self.updateInterval = updateInterval
    }

    func state(for conversationID: UUID) -> ConversationState? {
        states[conversationID]
    }

    private func updateStates(_ mutation: (inout [UUID: ConversationState]) -> Void) {
        var updatedStates = states
        mutation(&updatedStates)
        states = updatedStates
        reconcileBackgroundTasks()
    }

    private func reconcileBackgroundTasks() {
        let activeConversationIDs = Set(states.compactMap { entry in
            entry.value.isInProgress ? entry.key : nil
        })

        guard scenePhase == .background else {
            for conversationID in activeBackgroundTaskConversationIDs {
                backgroundTaskManager.endTask(for: conversationID)
            }
            activeBackgroundTaskConversationIDs.removeAll()
            return
        }

        for conversationID in activeConversationIDs.subtracting(activeBackgroundTaskConversationIDs) {
            let coordinator = self
            let didBegin = backgroundTaskManager.beginTask(for: conversationID) {
                Task { @MainActor in
                    coordinator.interruptGeneration(
                        for: conversationID,
                        errorDescription: L10n.Chat.backgroundInterruptedMessage
                    )
                }
            }

            if didBegin {
                activeBackgroundTaskConversationIDs.insert(conversationID)
            }
        }

        for conversationID in activeBackgroundTaskConversationIDs.subtracting(activeConversationIDs) {
            backgroundTaskManager.endTask(for: conversationID)
            activeBackgroundTaskConversationIDs.remove(conversationID)
        }
    }

    @discardableResult
    func startGeneration(message: Message, to conversationID: UUID, model: LLMModel?) -> Bool {
        guard tasks[conversationID] == nil, !(states[conversationID]?.isInProgress ?? false) else {
            return false
        }

        let generationID = UUID()

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

        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let coordinator = self else { return }
            let clock = ContinuousClock()

            var bufferedText = ""
            var lastFlush = clock.now

            func flushBuffer(force: Bool = false) async {
                guard !bufferedText.isEmpty else { return }
                guard force || lastFlush.duration(to: clock.now) >= updateInterval else { return }

                let flushed = bufferedText
                bufferedText = ""
                lastFlush = clock.now
                await coordinator.appendStreamedText(flushed, to: conversationID, generationID: generationID)
            }

            do {
                for try await token in stream {
                    try Task.checkCancellation()
                    bufferedText += token
                    await flushBuffer()
                }

                await flushBuffer(force: true)
                await coordinator.markCompleted(for: conversationID, generationID: generationID)
            } catch is CancellationError {
                await flushBuffer(force: true)
            } catch {
                await flushBuffer(force: true)
                await coordinator.markFailed(
                    for: conversationID,
                    generationID: generationID,
                    errorDescription: error.localizedDescription
                )
            }
        }

        tasks[conversationID] = TaskRecord(generationID: generationID, task: task)

        return true
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        scenePhase = newPhase
        reconcileBackgroundTasks()
    }

    func interruptGeneration(for conversationID: UUID, errorDescription: String) {
        guard let state = states[conversationID], state.isInProgress else {
            return
        }

        let existing = states[conversationID]
        let taskRecord = tasks.removeValue(forKey: conversationID)
        taskRecord?.task.cancel()

        updateStates { states in
            states[conversationID] = ConversationState(
                phase: .failed,
                streamedText: existing?.streamedText ?? "",
                errorDescription: errorDescription,
                terminalEventID: UUID()
            )
        }
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

    private func appendStreamedText(_ text: String, to conversationID: UUID, generationID: UUID) {
        guard !text.isEmpty else { return }
        guard tasks[conversationID]?.generationID == generationID else { return }

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

    private func markCompleted(for conversationID: UUID, generationID: UUID) {
        guard tasks[conversationID]?.generationID == generationID else { return }

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

    private func markFailed(for conversationID: UUID, generationID: UUID, errorDescription: String) {
        guard tasks[conversationID]?.generationID == generationID else { return }

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
