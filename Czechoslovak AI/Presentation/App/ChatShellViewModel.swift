import Combine
import Foundation
import SwiftUI

@MainActor
protocol SidebarConversationsManaging: AnyObject {
    var selectedConversationID: UUID? { get set }
    func createConversation(title: String?) async
}

@MainActor
final class ChatShellViewModel: ObservableObject {
    @Published private(set) var activeConversationID: UUID?
    @Published var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @Published var compactPath: [AppRoute] = []
    @Published var isSettingsPresented = false

    private var didBootstrap = false

    func bootstrapIfNeeded(
        using conversationsManager: any SidebarConversationsManaging,
        isCompactLayout: Bool
    ) async {
        guard !didBootstrap else { return }
        didBootstrap = true

        await conversationsManager.createConversation(title: nil)
        guard let createdConversationID = conversationsManager.selectedConversationID else { return }

        handleConversationSelection(id: createdConversationID, isCompactLayout: isCompactLayout)
        conversationsManager.selectedConversationID = nil
    }

    func handleConversationSelection(id: UUID, isCompactLayout: Bool) {
        activeConversationID = id
        if isCompactLayout {
            let route = AppRoute.chat(conversationID: id)
            if compactPath.last != route {
                compactPath.append(route)
            }
        } else {
            columnVisibility = .detailOnly
        }
    }

    func showSidebar() {
        columnVisibility = .all
    }

    func showSearchInSidebar() {
        columnVisibility = .all
    }

    func presentSettings() {
        isSettingsPresented = true
    }
}
