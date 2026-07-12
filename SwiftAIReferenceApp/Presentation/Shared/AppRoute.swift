import Foundation

enum AppRoute: Hashable {
    case chat(conversationID: UUID)
    case settings
}
