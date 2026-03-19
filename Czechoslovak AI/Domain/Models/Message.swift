import Foundation

public struct Message: Identifiable, Codable, Equatable {
    public let id: UUID
    public let role: Role
    public var text: String
    public let date: Date

    public enum Role: String, Codable {
        case user, assistant, system
    }

    public init(id: UUID = .init(), role: Role, text: String, date: Date = .init()) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
    }
}
