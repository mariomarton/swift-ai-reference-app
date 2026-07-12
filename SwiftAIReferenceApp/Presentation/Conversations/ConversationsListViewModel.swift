import Combine
import Foundation

protocol ConversationGenerationStateObserving: AnyObject {
    var statesPublisher: AnyPublisher<[UUID: MessageGenerationCoordinator.ConversationState], Never> { get }
}

@MainActor
final class ConversationsListViewModel: ObservableObject, SidebarConversationsManaging {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var generatingConversationIDs: Set<UUID> = []
    @Published var searchText: String = ""
    @Published var selectedConversationID: UUID?
    @Published private(set) var isLoading = false
    @Published var alert: PresentationAlert?
    
    private let loadConversationsUseCase: LoadConversationsUseCase
    private let loadRecentMessagesUseCase: LoadRecentMessagesUseCase
    private let searchConversationsUseCase: SearchConversationsUseCase
    private let deleteConversationUseCase: DeleteConversationUseCase
    private var generationObservationTask: Task<Void, Never>?
    private var searchableMessagesByConversationID: [UUID: [Message]] = [:]
    
    init(
        loadConversationsUseCase: LoadConversationsUseCase,
        loadRecentMessagesUseCase: LoadRecentMessagesUseCase,
        searchConversationsUseCase: SearchConversationsUseCase,
        deleteConversationUseCase: DeleteConversationUseCase,
        generationCoordinator: (any ConversationGenerationStateObserving)? = nil
    ) {
        self.loadConversationsUseCase = loadConversationsUseCase
        self.loadRecentMessagesUseCase = loadRecentMessagesUseCase
        self.searchConversationsUseCase = searchConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase

        if let generationCoordinator {
            generationObservationTask = Task { [weak self] in
                for await states in generationCoordinator.statesPublisher.values {
                    let generatingConversationIDs = Set(states.compactMap { entry in
                        entry.value.isInProgress ? entry.key : nil
                    })
                    self?.generatingConversationIDs = generatingConversationIDs
                }
            }
        }
    }

    func stopGenerationObservation() {
        generationObservationTask?.cancel()
        generationObservationTask = nil
    }

    func isGenerating(conversationID: UUID) -> Bool {
        generatingConversationIDs.contains(conversationID)
    }

    var displayedConversations: [Conversation] {
        let searchableConversations = conversations.map { conversation in
            var enrichedConversation = conversation
            if let messages = searchableMessagesByConversationID[conversation.id] {
                enrichedConversation.messages = messages
            }
            return enrichedConversation
        }

        let matchedIDs = Set(
            searchConversationsUseCase.execute(conversations: searchableConversations, query: searchText)
                .map(\.id)
        )

        return conversations.filter { matchedIDs.contains($0.id) }
    }

    var hasActiveSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func loadConversations() async {
        guard !isLoading else { return }
        isLoading = true
        alert = nil
        defer { isLoading = false }
        
        do {
            let loadedConversations = try await loadConversationsUseCase.execute()
            searchableMessagesByConversationID = await loadSearchableMessages(for: loadedConversations)
            conversations = loadedConversations
        } catch {
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorLoadTitle,
                message: error.localizedDescription,
                isRetryable: true
            )
        }
    }
    
    func startConversation() -> UUID {
        alert = nil

        let conversationID = UUID()
        selectedConversationID = conversationID
        return conversationID
    }
    
    func selectConversation(id: UUID) {
        selectedConversationID = id
    }
    
    func deleteConversation(id: UUID) async {
        // Optimistic removal: update UI immediately, roll back if the operation fails
        let snapshot = conversations
        let messageSnapshot = searchableMessagesByConversationID
        conversations.removeAll { $0.id == id }
        searchableMessagesByConversationID.removeValue(forKey: id)
        if selectedConversationID == id {
            selectedConversationID = nil
        }
        
        do {
            try await deleteConversationUseCase.execute(id: id)
        } catch {
            conversations = snapshot
            searchableMessagesByConversationID = messageSnapshot
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorDeleteTitle,
                message: error.localizedDescription
            )
        }
    }

    private func loadSearchableMessages(for conversations: [Conversation]) async -> [UUID: [Message]] {
        var messageIndex: [UUID: [Message]] = [:]
        for conversation in conversations {
            let messages = (try? await loadRecentMessagesUseCase.loadRecentMessages(for: conversation.id, limit: nil)) ?? []
            messageIndex[conversation.id] = messages
        }
        return messageIndex
    }
}
