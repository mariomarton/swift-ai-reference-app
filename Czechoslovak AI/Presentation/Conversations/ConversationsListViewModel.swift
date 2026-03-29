import Combine
import Foundation

@MainActor
final class ConversationsListViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published var selectedConversationID: UUID?
    @Published private(set) var isLoading = false
    @Published var alert: PresentationAlert?
    
    private let loadConversationsUseCase: LoadConversationsUseCase
    private let createConversationUseCase: CreateConversationUseCase
    private let deleteConversationUseCase: DeleteConversationUseCase
    
    init(
        loadConversationsUseCase: LoadConversationsUseCase,
        createConversationUseCase: CreateConversationUseCase,
        deleteConversationUseCase: DeleteConversationUseCase
    ) {
        self.loadConversationsUseCase = loadConversationsUseCase
        self.createConversationUseCase = createConversationUseCase
        self.deleteConversationUseCase = deleteConversationUseCase
    }
    
    func loadConversations() async {
        guard !isLoading else { return }
        isLoading = true
        alert = nil
        defer { isLoading = false }
        
        do {
            conversations = try await loadConversationsUseCase.execute()
        } catch {
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorLoadTitle,
                message: error.localizedDescription,
                isRetryable: true
            )
        }
    }
    
    func createConversation(title: String?) async {
        alert = nil
        
        do {
            let created = try await createConversationUseCase.execute(title: title)
            conversations.insert(created, at: 0)
            selectedConversationID = created.id
        } catch {
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorCreateTitle,
                message: error.localizedDescription
            )
        }
    }
    
    func selectConversation(id: UUID) {
        selectedConversationID = id
    }
    
    func deleteConversation(id: UUID) async {
        // Optimistic removal: update UI immediately, roll back if the operation fails
        let snapshot = conversations
        conversations.removeAll { $0.id == id }
        if selectedConversationID == id {
            selectedConversationID = nil
        }
        
        do {
            try await deleteConversationUseCase.execute(id: id)
        } catch {
            conversations = snapshot
            alert = PresentationAlert(
                title: L10n.ConversationsList.errorDeleteTitle,
                message: error.localizedDescription
            )
        }
    }
}
