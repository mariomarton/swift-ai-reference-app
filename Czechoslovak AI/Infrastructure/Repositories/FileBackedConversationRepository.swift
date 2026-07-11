import Foundation

/// A simple file-backed implementation of `ConversationRepository`.
///
/// - Stores conversations as an array of `Conversation` encoded with `JSONEncoder` at the provided `storageURL`.
/// - Uses an in-memory cache backed by an atomic disk write on updates.
/// - Uses Swift `actor` to ensure safe concurrent access.
///
/// This implementation is intended for local/offline use and development. Swap with a database-backed
/// implementation by replacing this concrete type without changing the domain/use-case layer.
public actor FileBackedConversationRepository: ConversationRepository {
    public enum StorageError: Error {
        case failedToCreateDirectory
        case failedToWriteData(Error)
        case failedToReadData(Error)
        case decodeError(Error)
        case conversationNotFound
    }

    private let storageURL: URL
    nonisolated(unsafe) private let fileManager: FileManager
    private var cache: [Conversation]

    /// Initialize with a specific storage URL, or default to Application Support/CzechoslovakAI/conversations.json
    /// - Parameters:
    ///   - storageURL: if nil, will use Application Support/CzechoslovakAI/conversations.json
    ///   - fileManager: injected for easier tests
    public init(storageURL: URL? = nil, fileManager injectedFileManager: FileManager = .default) throws {
        self.fileManager = injectedFileManager

        if let storageURL = storageURL {
            self.storageURL = storageURL
            try FileBackedConversationRepository.ensureDirectoryExists(for: storageURL, fileManager: injectedFileManager)
        } else {
            let appSupport = try injectedFileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = appSupport.appendingPathComponent("CzechoslovakAI", isDirectory: true)
            try injectedFileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("conversations.json")
        }

        do {
            self.cache = try FileBackedConversationRepository.loadConversations(from: self.storageURL, fileManager: injectedFileManager)
        } catch {
            // If loading fails, prefer starting with an empty cache and propagate the error only on demand
            self.cache = []
            // Note: we don't throw here so the repo can still be used, but callers will get persistence errors when saving
        }
    }

    public func createConversation(id: UUID, title: String?) async throws -> Conversation {
        let conversation = await Conversation(
            id: id,
            title: title,
            messages: [],
            selectedModel: nil,
            createdAt: .init(),
            updatedAt: .init()
        )
        cache.append(conversation)
        do {
            try writeCacheToDisk()
        } catch {
            throw StorageError.failedToWriteData(error)
        }
        return conversation
    }

    public func listConversations() async throws -> [Conversation] {
        // Return conversations sorted by most recently updated first, for better UX in recents lists
        return cache.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func loadConversation(id: UUID) async throws -> Conversation? {
        return cache.first { $0.id == id }
    }

    public func updateConversation(_ conversation: Conversation) async throws {
        // Find and replace the conversation in cache
        if let index = cache.firstIndex(where: { $0.id == conversation.id }) {
            cache[index] = conversation
            do {
                try writeCacheToDisk()
            } catch {
                throw StorageError.failedToWriteData(error)
            }
        } else {
            throw StorageError.conversationNotFound
        }
    }

    public func deleteConversation(id: UUID) async throws {
        guard cache.contains(where: { $0.id == id }) else {
            throw StorageError.conversationNotFound
        }
        cache.removeAll { $0.id == id }
        do {
            try writeCacheToDisk()
        } catch {
            throw StorageError.failedToWriteData(error)
        }
    }

    // MARK: - Disk IO

    private func writeCacheToDisk() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(cache)

        let tempURL = storageURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tempURL, options: .atomic)

            if fileManager.fileExists(atPath: storageURL.path) {
                do {
                    _ = try fileManager.replaceItemAt(storageURL, withItemAt: tempURL)
                } catch {
                    try? fileManager.removeItem(at: storageURL)
                    try fileManager.moveItem(at: tempURL, to: storageURL)
                }
            } else {
                try fileManager.moveItem(at: tempURL, to: storageURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    private static func loadConversations(from url: URL, fileManager: FileManager) throws -> [Conversation] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let conversations = try decoder.decode([Conversation].self, from: data)
            return conversations
        } catch let err as DecodingError {
            throw StorageError.decodeError(err)
        } catch {
            throw StorageError.failedToReadData(error)
        }
    }

    private static func ensureDirectoryExists(for fileURL: URL, fileManager: FileManager) throws {
        let dir = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: dir.path) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw StorageError.failedToCreateDirectory
            }
        }
    }
}
