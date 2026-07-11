import Foundation

public struct LLMModel: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let path: String?

    public init(id: String, name: String, path: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
    }
}
