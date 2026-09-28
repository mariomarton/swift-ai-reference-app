import Combine
import Foundation
import SwiftUI

@MainActor
protocol SidebarConversationsManaging: AnyObject {
    var selectedConversationID: UUID? { get set }
    func startConversation() -> UUID
}

@MainActor
final class ChatShellViewModel: ObservableObject {
    @Published private(set) var activeConversationID: UUID?
    @Published var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @Published var compactPath: [AppRoute] = []
    @Published var isSettingsPresented = false

    private var didBootstrap = false

    var isSidebarVisible: Bool {
        columnVisibility == .all
    }

    nonisolated deinit {}

    func bootstrapIfNeeded(
        using conversationsManager: any SidebarConversationsManaging,
        isCompactLayout: Bool
    ) async {
        guard !didBootstrap else { return }
        didBootstrap = true

        let createdConversationID = conversationsManager.startConversation()

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

    func toggleSidebar() {
        columnVisibility = isSidebarVisible ? .detailOnly : .all
    }

    func showSearchInSidebar() {
        columnVisibility = .all
    }

    func shouldShowConversationsListSettingsButton(isCompactLayout: Bool) -> Bool {
        guard !isCompactLayout else {
            return true
        }
        return columnVisibility == .detailOnly
    }

    func presentSettings() {
        isSettingsPresented = true
    }
}
