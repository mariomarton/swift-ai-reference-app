import Foundation

/// A file-backed implementation of `MessageRepository` with per-conversation message storage.
///
/// - Stores messages in per-conversation subdirectories as JSON arrays.
/// - Uses an in-memory cache per conversation.
/// - Uses Swift `actor` to ensure safe concurrent access.
///
/// This implementation is intended for local/offline use and development. Swap with a database-backed
/// implementation by replacing this concrete type without changing the domain/use-case layer.
public actor FileBackedMessageRepository: MessageRepository {
    public enum StorageError: Error {
        case failedToCreateDirectory
        case failedToWriteData(Error)
        case failedToReadData(Error)
        case decodeError(Error)
    }

    private let storageURL: URL  // Base directory for all messages
    nonisolated(unsafe) private let fileManager: FileManager
    private var cache: [UUID: [Message]] = [:]  // Cache per conversation

    /// Initialize with a specific storage URL, or default to Application Support/CzechoslovakAI/messages
    /// - Parameters:
    ///   - storageURL: base directory for message storage; if nil, uses Application Support/CzechoslovakAI/messages
    ///   - fileManager: injected for easier tests
    public init(storageURL: URL? = nil, fileManager injectedFileManager: FileManager = .default) throws {
        self.fileManager = injectedFileManager

        if let storageURL = storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = try injectedFileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = appSupport.appendingPathComponent("CzechoslovakAI", isDirectory: true)
            try injectedFileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("messages", isDirectory: true)
        }

        // Ensure base messages directory exists
        try injectedFileManager.createDirectory(at: self.storageURL, withIntermediateDirectories: true)
    }

    public func loadMessages(for conversationID: UUID) async throws -> [Message] {
        // Return from cache if available
        if let cached = cache[conversationID] {
            return cached
        }

        // Load from disk
        let messages = try loadMessagesFromDisk(for: conversationID)
        cache[conversationID] = messages
        return messages
    }

    public func save(message: Message, to conversationID: UUID) async throws {
        // Ensure cache exists for this conversation
        if cache[conversationID] == nil {
            cache[conversationID] = []
        }
        cache[conversationID]?.append(message)

        do {
            try writeConversationCacheToDisk(for: conversationID)
        } catch {
            throw StorageError.failedToWriteData(error)
        }
    }

    public func clearMessages(for conversationID: UUID) async throws {
        cache[conversationID] = []
        do {
            try writeConversationCacheToDisk(for: conversationID)
        } catch {
            throw StorageError.failedToWriteData(error)
        }
    }

    public func deleteMessages(for conversationID: UUID) async throws {
        cache.removeValue(forKey: conversationID)
        let dirURL = conversationDirectory(for: conversationID)
        guard fileManager.fileExists(atPath: dirURL.path) else { return }
        do {
            try fileManager.removeItem(at: dirURL)
        } catch {
            throw StorageError.failedToWriteData(error)
        }
    }

    public func clearAll() async throws {
        cache.removeAll()
        do {
            // Remove entire messages directory
            try fileManager.removeItem(at: storageURL)
            // Recreate it empty
            try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        } catch {
            throw StorageError.failedToWriteData(error)
        }
    }

    // MARK: - Private Disk IO

    private func conversationMessagesURL(for conversationID: UUID) -> URL {
        storageURL.appendingPathComponent(conversationID.uuidString, isDirectory: true)
            .appendingPathComponent("messages.json")
    }

    private func conversationDirectory(for conversationID: UUID) -> URL {
        storageURL.appendingPathComponent(conversationID.uuidString, isDirectory: true)
    }

    private func loadMessagesFromDisk(for conversationID: UUID) throws -> [Message] {
        let url = conversationMessagesURL(for: conversationID)
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let messages = try decoder.decode([Message].self, from: data)
            return messages
        } catch let err as DecodingError {
            throw StorageError.decodeError(err)
        } catch {
            throw StorageError.failedToReadData(error)
        }
    }

    private func writeConversationCacheToDisk(for conversationID: UUID) throws {
        let dirURL = conversationDirectory(for: conversationID)
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let messages = cache[conversationID] ?? []
        let data = try encoder.encode(messages)

        let fileURL = conversationMessagesURL(for: conversationID)
        let tempURL = fileURL.appendingPathExtension("tmp")

        do {
            try data.write(to: tempURL, options: .atomic)

            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
                } catch {
                    try? fileManager.removeItem(at: fileURL)
                    try fileManager.moveItem(at: tempURL, to: fileURL)
                }
            } else {
                try fileManager.moveItem(at: tempURL, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }
}
