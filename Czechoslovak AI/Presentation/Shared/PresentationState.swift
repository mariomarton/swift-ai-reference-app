import Foundation

struct PresentationAlert: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let isRetryable: Bool

    init(id: UUID = UUID(), title: String, message: String, isRetryable: Bool = false) {
        self.id = id
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }
}
