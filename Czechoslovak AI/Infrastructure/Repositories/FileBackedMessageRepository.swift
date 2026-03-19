import Foundation

/// A simple file-backed implementation of `MessageRepository`.
///
/// - Stores messages as an array of `Message` encoded with `JSONEncoder` at the provided `storageURL`.
/// - Uses an in-memory cache backed by an atomic disk write on updates.
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

    private let storageURL: URL
    private let fileManager: FileManager
    private var cache: [Message]

    /// Initialize with a specific storage URL, or default to Application Support/CzechoslovakAI/messages.json
    /// - Parameters:
    ///   - storageURL: if nil, will use Application Support/CzechoslovakAI/messages.json
    ///   - fileManager: injected for easier tests
    public init(storageURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        if let storageURL = storageURL {
            self.storageURL = storageURL
            // ensure directory exists
            try FileBackedMessageRepository.ensureDirectoryExists(for: storageURL, fileManager: fileManager)
        } else {
            let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = appSupport.appendingPathComponent("CzechoslovakAI", isDirectory: true)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("messages.json")
        }

        // load existing messages from disk, or start with an empty cache
        do {
            self.cache = try FileBackedMessageRepository.loadMessages(from: self.storageURL, fileManager: fileManager)
        } catch {
            // If loading fails, prefer starting with an empty cache and propogate the error only on demand
            self.cache = []
            // Note: we don't throw here so the repo can still be used, but callers will get persistence errors when saving
        }
    }

    public func loadRecentMessages() async throws -> [Message] {
        return cache
    }

    public func save(message: Message) async throws {
        cache.append(message)
        do {
            try writeCacheToDisk()
        } catch {
            throw StorageError.failedToWriteData(error)
        }
    }

    public func clearAll() async throws {
        cache.removeAll()
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
        // Keep default date encoding strategy so encode/decode stay consistent
        let data = try encoder.encode(cache)

        // Write atomically via a temporary file in the same directory
        let tempURL = storageURL.appendingPathExtension("tmp")
        do {
            try data.write(to: tempURL, options: .atomic)

            if fileManager.fileExists(atPath: storageURL.path) {
                // Try to replace; if it fails fall back to removing and moving
                do {
                    _ = try fileManager.replaceItemAt(storageURL, withItemAt: tempURL)
                } catch {
                    // fallback
                    try? fileManager.removeItem(at: storageURL)
                    try fileManager.moveItem(at: tempURL, to: storageURL)
                }
            } else {
                try fileManager.moveItem(at: tempURL, to: storageURL)
            }
        } catch {
            // Clean up temp file if exists
            try? fileManager.removeItem(at: tempURL)
            throw error
        }
    }

    private static func loadMessages(from url: URL, fileManager: FileManager) throws -> [Message] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
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
