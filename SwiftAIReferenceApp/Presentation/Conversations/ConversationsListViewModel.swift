import Combine
import Foundation

protocol ConversationGenerationStateObserving: AnyObject {
    var statesPublisher: AnyPublisher<[UUID: MessageGenerationCoordinator.ConversationState], Never> { get }
}

/// Owns sidebar conversation state, search hydration, and generation badges.
@MainActor
final class ConversationsListViewModel: ObservableObject, SidebarConversationsManaging {
    struct ConversationRenameContext: Identifiable, Equatable {
        let conversationID: UUID

        var id: UUID { conversationID }
    }

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var generatingConversationIDs: Set<UUID> = []
    @Published var searchText: String = ""
    @Published var selectedConversationID: UUID?
    @Published private(set) var isLoading = false
    @Published var alert: PresentationAlert?
    @Published var renameConversationContext: ConversationRenameContext?
    @Published var renameDraftTitle: String = ""
    
    private let loadConversationsUseCase: LoadConversationsUseCase
    private let loadRecentMessagesUseCase: LoadRecentMessagesUseCase
    private let searchConversationsUseCase: SearchConversationsUseCase
    private let deleteConversationUseCase: DeleteConversationUseCase
    private let renameConversationUseCase: RenameConversationUseCase
    private var generationObservationTask: Task<Void, Never>?
    private var searchableMessagesByConversationID: [UUID: [Message]] = [:]
    
    init(
        loadConversationsUseCase: LoadConversationsUseCase,
        loadRecentMessagesUseCase: LoadRecentMessagesUseCase,
        searchConversationsUseCase: SearchConversationsUseCase,
        deleteConversationUseCase: DeleteConversationUseCase,
        renameConversationUseCase: RenameConversationUseCase,
        generationCoordinator: (any ConversationGenerationStateObserving)? = nil
    ) {
        self.loadConversationsUseCase = loadConversationsUseCase
        self.loadRecentMessagesUseCase = loadRecentMessagesUseCase
        self.searchConversationsUseCase = searchConversationsUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
        self.renameConversationUseCase = renameConversationUseCase

        if let generationCoordinator {
            // Keep the sidebar badge state in sync with active generations without polling.
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

    nonisolated deinit {}

    func stopGenerationObservation() {
        generationObservationTask?.cancel()
        generationObservationTask = nil
    }

    func isGenerating(conversationID: UUID) -> Bool {
        generatingConversationIDs.contains(conversationID)
    }

    var displayedConversations: [Conversation] {
        // Search uses cached recent messages so message text can match without reloading on every keystroke.
        let searchableConversations = conversations.map { conversation in
            var enrichedConversation = conversation
            if let messages = searchableMessagesByConversationID[conversation.id] {
                enrichedConversation.messages = messages
            }
            return enrichedConversation
        }

        let matchedIDs = Set(
            searchConversationsUseCase.search(conversations: searchableConversations, query: searchText)
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
            let loadedConversations = try await loadConversationsUseCase.loadConversations()
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
        // Optimistic removal keeps the list responsive; the snapshots let us roll back on failure.
        let snapshot = conversations
        let messageSnapshot = searchableMessagesByConversationID
        conversations.removeAll { $0.id == id }
        searchableMessagesByConversationID.removeValue(forKey: id)
        if selectedConversationID == id {
            selectedConversationID = nil
        }
        
        do {
            try await deleteConversationUseCase.deleteConversation(id: id)
        } catch {
            conversations = snapshot
            searchableMessagesByConversationID = messageSnapshot
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorDeleteTitle,
                message: error.localizedDescription
            )
        }
    }

    func beginRenaming(conversation: Conversation) {
        alert = nil
        renameDraftTitle = conversation.title ?? ""
        renameConversationContext = ConversationRenameContext(conversationID: conversation.id)
    }

    func cancelConversationRename() {
        renameConversationContext = nil
        renameDraftTitle = ""
    }

    var canSubmitConversationRename: Bool {
        !renameDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func commitConversationRename() async {
        guard let context = renameConversationContext else { return }

        alert = nil
        do {
            let updatedConversation = try await renameConversationUseCase.renameConversation(
                id: context.conversationID,
                title: renameDraftTitle
            )

            if let index = conversations.firstIndex(where: { $0.id == updatedConversation.id }) {
                conversations[index] = updatedConversation
            }

            cancelConversationRename()
        } catch {
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorRenameTitle,
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
