import XCTest
@testable import SwiftAIReferenceApp

@MainActor
final class FileBackedMessageRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var storageURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storageURL = tempDir.appendingPathComponent("messages", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storageURL = nil
        try super.tearDownWithError()
    }

    func testSaveAndLoadPersistsMessagesInConversation() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)

        let conversationID = UUID()
        let msg1 = Message(role: .user, text: "Hello")
        try await repo.save(message: msg1, to: conversationID)

        let loaded = try await repo.loadMessages(for: conversationID)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0], msg1)

        // Create a new repo instance pointing to same storage to ensure persistence across instances
        let repo2 = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)
        let loaded2 = try await repo2.loadMessages(for: conversationID)
        XCTAssertEqual(loaded2.count, 1)
        XCTAssertEqual(loaded2[0], msg1)
    }

    func testClearMessagesForSpecificConversation() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)

        let conv1 = UUID()
        let conv2 = UUID()

        try await repo.save(message: Message(role: .user, text: "Conv1"), to: conv1)
        try await repo.save(message: Message(role: .user, text: "Conv2"), to: conv2)

        try await repo.clearMessages(for: conv1)

        let loaded1 = try await repo.loadMessages(for: conv1)
        let loaded2 = try await repo.loadMessages(for: conv2)

        XCTAssertTrue(loaded1.isEmpty)
        XCTAssertEqual(loaded2.count, 1)
    }

    func testClearAllRemovesAllConversations() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)

        let conv1 = UUID()
        let conv2 = UUID()

        try await repo.save(message: Message(role: .user, text: "one"), to: conv1)
        try await repo.save(message: Message(role: .user, text: "two"), to: conv2)

        try await repo.clearAll()

        let loaded1 = try await repo.loadMessages(for: conv1)
        let loaded2 = try await repo.loadMessages(for: conv2)

        XCTAssertTrue(loaded1.isEmpty)
        XCTAssertTrue(loaded2.isEmpty)
    }

    func testConversationIsolation() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)

        let conv1 = UUID()
        let conv2 = UUID()

        let msg1 = Message(role: .user, text: "Message for Conv1")
        let msg2 = Message(role: .user, text: "Message for Conv2")

        try await repo.save(message: msg1, to: conv1)
        try await repo.save(message: msg2, to: conv2)

        let conv1Messages = try await repo.loadMessages(for: conv1)
        let conv2Messages = try await repo.loadMessages(for: conv2)

        XCTAssertEqual(conv1Messages.count, 1)
        XCTAssertEqual(conv2Messages.count, 1)
        XCTAssertEqual(conv1Messages[0].text, "Message for Conv1")
        XCTAssertEqual(conv2Messages[0].text, "Message for Conv2")
    }

    func testConcurrentWritesAreSafePerConversation() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)

        let conversationID = UUID()
        let messages = (0..<10).map { i in Message(role: .user, text: "m\(i)") }

        await withTaskGroup(of: Void.self) { group in
            for msg in messages {
                group.addTask {
                    try? await repo.save(message: msg, to: conversationID)
                }
            }
        }

        let loaded = try await repo.loadMessages(for: conversationID)
        XCTAssertEqual(loaded.count, 10)
    }

    func testDeleteMessagesRemovesDirAndEvictsCache() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)
        let conv1 = UUID()
        let conv2 = UUID()

        try await repo.save(message: Message(role: .user, text: "hi"), to: conv1)
        try await repo.save(message: Message(role: .user, text: "hey"), to: conv2)

        try await repo.deleteMessages(for: conv1)

        // conv1 should be gone from cache and disk
        let afterDelete = try await repo.loadMessages(for: conv1)
        XCTAssertTrue(afterDelete.isEmpty)

        // conv2 should be untouched
        let conv2Messages = try await repo.loadMessages(for: conv2)
        XCTAssertEqual(conv2Messages.count, 1)

        // Verify the disk directory was actually removed
        let conv1Dir = storageURL.appendingPathComponent(conv1.uuidString, isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: conv1Dir.path))
    }

    func testDeleteMessagesOnNonexistentConversationDoesNotThrow() async throws {
        let repo = try FileBackedMessageRepository(storageURL: storageURL, fileManager: FileManager.default)
        // Should not throw even if there is nothing to delete
        try await repo.deleteMessages(for: UUID())
    }
}
