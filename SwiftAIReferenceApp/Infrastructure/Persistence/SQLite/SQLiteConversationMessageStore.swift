import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteStorageError: LocalizedError {
    case failedToCreateDirectory(URL, underlying: Error)
    case failedToOpenDatabase(URL)
    case failedToConfigureDatabase(String)
    case failedToPrepareStatement(String)
    case failedToBindParameter(String)
    case failedToExecuteStatement(String)
    case failedToRunTransaction(String)
    case invalidRow

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let url, let underlying):
            return "Failed to create SQLite storage directory at \(url.path): \(underlying.localizedDescription)"
        case .failedToOpenDatabase(let url):
            return "Failed to open SQLite database at \(url.path)"
        case .failedToConfigureDatabase(let message):
            return "Failed to configure SQLite database: \(message)"
        case .failedToPrepareStatement(let sql):
            return "Failed to prepare SQLite statement: \(sql)"
        case .failedToBindParameter(let message):
            return "Failed to bind SQLite parameter: \(message)"
        case .failedToExecuteStatement(let message):
            return "Failed to execute SQLite statement: \(message)"
        case .failedToRunTransaction(let message):
            return "Failed to run SQLite transaction: \(message)"
        case .invalidRow:
            return "SQLite returned an invalid row"
        }
    }
}

/// Shared SQLite store for conversations and messages.
///
/// It owns schema access, migration, and recency ordering so the repository adapters stay thin.
final class SQLiteConversationMessageStore: @unchecked Sendable {
    private enum Schema {
        // Bump this when the database schema changes.
        static let version: Int64 = 2
    }

    private let lock = NSRecursiveLock()
    private let databaseURL: URL
    private var database: OpaquePointer?

    init(storageURL: URL? = nil, fileManager: FileManager = .default) throws {
        if let storageURL {
            self.databaseURL = storageURL
        } else {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = appSupport.appendingPathComponent("SwiftAIReferenceApp", isDirectory: true)
            try Self.ensureDirectoryExists(at: directory, fileManager: fileManager)
            self.databaseURL = directory.appendingPathComponent("chat.sqlite3")
        }

        try Self.ensureDirectoryExists(at: self.databaseURL.deletingLastPathComponent(), fileManager: fileManager)
        try openDatabase()
        try configureDatabase()
        try installSchemaIfNeeded()
    }

    deinit {
        if let database {
            sqlite3_close_v2(database)
        }
    }

    func createConversation(
        id: UUID,
        title: String?,
        titleOrigin: ConversationTitleOrigin = .manual,
        selectedModel: LLMModel? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) throws {
        try locked {
            try performTransaction {
                _ = try execute(
                    """
                    INSERT OR IGNORE INTO conversations (
                        id,
                        title,
                        title_origin,
                        selected_model_id,
                        selected_model_name,
                        selected_model_path,
                        created_at,
                        updated_at,
                        message_count,
                        last_message_at,
                        last_message_preview
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, NULL)
                    """,
                    bind: { statement in
                        try Self.bindUUID(id, at: 1, on: statement)
                        try Self.bindOptionalText(title, at: 2, on: statement)
                        try Self.bindText(titleOrigin.rawValue, at: 3, on: statement)
                        try Self.bindOptionalText(selectedModel?.id, at: 4, on: statement)
                        try Self.bindOptionalText(selectedModel?.name, at: 5, on: statement)
                        try Self.bindOptionalText(nil, at: 6, on: statement)
                        try Self.bindDouble(createdAt.timeIntervalSince1970, at: 7, on: statement)
                        try Self.bindDouble(updatedAt.timeIntervalSince1970, at: 8, on: statement)
                    }
                )

                try refreshSearchTerms(for: id, updatedAt: nil)
            }
        }
    }

    func listConversations() throws -> [Conversation] {
        try locked {
            // Sidebar recents should stay newest-first, with created-at as a tie breaker.
            try fetchConversations(
                sql: """
                SELECT
                    id,
                    title,
                    title_origin,
                    selected_model_id,
                    selected_model_name,
                    selected_model_path,
                    created_at,
                    updated_at
                FROM conversations
                ORDER BY updated_at DESC, created_at DESC
                """
            )
        }
    }

    func loadConversation(id: UUID) throws -> Conversation? {
        try locked {
            try fetchConversation(
                sql: """
                SELECT
                    id,
                    title,
                    title_origin,
                    selected_model_id,
                    selected_model_name,
                    selected_model_path,
                    created_at,
                    updated_at
                FROM conversations
                WHERE id = ?
                LIMIT 1
                """,
                bind: { statement in
                    try Self.bindUUID(id, at: 1, on: statement)
                }
            )
        }
    }

    func updateConversation(_ conversation: Conversation) throws {
        try locked {
            try performTransaction {
                let rowsChanged = try execute(
                    """
                    UPDATE conversations
                    SET title = ?,
                        title_origin = ?,
                        selected_model_id = ?,
                        selected_model_name = ?,
                        selected_model_path = ?,
                        updated_at = ?
                    WHERE id = ?
                    """,
                    bind: { statement in
                        try Self.bindOptionalText(conversation.title, at: 1, on: statement)
                        try Self.bindText(conversation.titleOrigin.rawValue, at: 2, on: statement)
                        try Self.bindOptionalText(conversation.selectedModel?.id, at: 3, on: statement)
                        try Self.bindOptionalText(conversation.selectedModel?.name, at: 4, on: statement)
                        try Self.bindOptionalText(nil, at: 5, on: statement)
                        try Self.bindDouble(conversation.updatedAt.timeIntervalSince1970, at: 6, on: statement)
                        try Self.bindUUID(conversation.id, at: 7, on: statement)
                    }
                )

                guard rowsChanged > 0 else {
                    throw SQLiteStorageError.failedToExecuteStatement("Conversation not found")
                }

                try refreshSearchTerms(for: conversation.id, updatedAt: nil)
            }
        }
    }

    func deleteConversation(id: UUID) throws {
        try locked {
            let rowsChanged = try performTransaction {
                try execute(
                    "DELETE FROM conversations WHERE id = ?",
                    bind: { statement in
                        try Self.bindUUID(id, at: 1, on: statement)
                    }
                )
            }

            guard rowsChanged > 0 else {
                throw SQLiteStorageError.failedToExecuteStatement("Conversation not found")
            }
        }
    }

    func saveMessage(_ message: Message, to conversationID: UUID) throws {
        try locked {
            try performTransaction {
                try ensureConversationExists(id: conversationID, createdAt: message.date, updatedAt: message.date)
                _ = try execute(
                    """
                    INSERT INTO messages (id, conversation_id, role, text, date)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    bind: { statement in
                        try Self.bindUUID(message.id, at: 1, on: statement)
                        try Self.bindUUID(conversationID, at: 2, on: statement)
                        try Self.bindText(message.role.rawValue, at: 3, on: statement)
                        try Self.bindText(message.text, at: 4, on: statement)
                        try Self.bindDouble(message.date.timeIntervalSince1970, at: 5, on: statement)
                    }
                )
                try refreshConversationSummary(for: conversationID, updatedAt: message.date)
            }
        }
    }

    func loadMessages(for conversationID: UUID) throws -> [Message] {
        try locked {
            try fetchMessages(
                sql: """
                SELECT id, conversation_id, role, text, date
                FROM messages
                WHERE conversation_id = ?
                ORDER BY date ASC, rowid ASC
                """,
                bind: { statement in
                    try Self.bindUUID(conversationID, at: 1, on: statement)
                }
            )
        }
    }

    func clearMessages(for conversationID: UUID) throws {
        try locked {
            try performTransaction {
                _ = try execute(
                    "DELETE FROM messages WHERE conversation_id = ?",
                    bind: { statement in
                        try Self.bindUUID(conversationID, at: 1, on: statement)
                    }
                )

                guard try conversationExists(id: conversationID) else {
                    return
                }

                try refreshConversationSummary(for: conversationID, updatedAt: nil)
            }
        }
    }

    func deleteMessages(for conversationID: UUID) throws {
        try clearMessages(for: conversationID)
    }

    func clearAllMessages() throws {
        try locked {
            try performTransaction {
                _ = try execute("DELETE FROM messages")
                _ = try execute("DELETE FROM conversation_search_terms")
                _ = try execute(
                    """
                    UPDATE conversations
                    SET message_count = 0,
                        last_message_at = NULL,
                        last_message_preview = NULL
                    """
                )

                let conversations = try fetchConversations(
                    sql: """
                    SELECT
                        id,
                        title,
                        title_origin,
                        selected_model_id,
                        selected_model_name,
                        selected_model_path,
                        created_at,
                        updated_at
                    FROM conversations
                    """
                )

                for conversation in conversations {
                    try refreshSearchTerms(for: conversation.id, updatedAt: nil)
                }
            }
        }
    }

    func searchConversations(matching query: String) throws -> [Conversation] {
        try locked {
            let tokens = Self.tokenize(query)
            guard !tokens.isEmpty else {
                return try listConversations()
            }

            let placeholders = Array(repeating: "?", count: tokens.count).joined(separator: ", ")
            return try fetchConversations(
                sql: """
                SELECT
                    c.id,
                    c.title,
                    c.title_origin,
                    c.selected_model_id,
                    c.selected_model_name,
                    c.selected_model_path,
                    c.created_at,
                    c.updated_at
                FROM conversations c
                JOIN (
                    SELECT conversation_id
                    FROM conversation_search_terms
                    WHERE term IN (\(placeholders))
                    GROUP BY conversation_id
                    HAVING COUNT(DISTINCT term) = ?
                ) matches ON matches.conversation_id = c.id
                ORDER BY c.updated_at DESC, c.created_at DESC
                """,
                bind: { statement in
                    for (index, token) in tokens.enumerated() {
                        try Self.bindText(token, at: Int32(index + 1), on: statement)
                    }
                    try Self.bindInt64(Int64(tokens.count), at: Int32(tokens.count + 1), on: statement)
                }
            )
        }
    }

    // MARK: - Private helpers

    private func locked<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func performTransaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let result = try body()
            try execute("COMMIT TRANSACTION")
            return result
        } catch {
            do {
                try execute("ROLLBACK TRANSACTION")
            } catch {
                throw SQLiteStorageError.failedToRunTransaction(error.localizedDescription)
            }
            throw error
        }
    }

    @discardableResult
    private func execute(_ sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> Int32 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        if let bind {
            try bind(statement)
        }

        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                break
            }
            if stepResult == SQLITE_ROW {
                continue
            }
            throw SQLiteStorageError.failedToExecuteStatement(Self.lastErrorMessage(database))
        }

        guard let database else {
            throw SQLiteStorageError.failedToOpenDatabase(databaseURL)
        }
        return sqlite3_changes(database)
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let database else {
            throw SQLiteStorageError.failedToOpenDatabase(databaseURL)
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteStorageError.failedToPrepareStatement(Self.lastErrorMessage(database) + " | SQL: \(sql)")
        }

        return statement
    }

    private func ensureConversationExists(id: UUID, createdAt: Date, updatedAt: Date) throws {
        _ = try execute(
            """
            INSERT OR IGNORE INTO conversations (
                id,
                title,
                title_origin,
                selected_model_id,
                selected_model_name,
                selected_model_path,
                created_at,
                updated_at,
                message_count,
                last_message_at,
                last_message_preview
            ) VALUES (?, NULL, ?, NULL, NULL, NULL, ?, ?, 0, NULL, NULL)
            """,
            bind: { statement in
                try Self.bindUUID(id, at: 1, on: statement)
                try Self.bindText(ConversationTitleOrigin.manual.rawValue, at: 2, on: statement)
                try Self.bindDouble(createdAt.timeIntervalSince1970, at: 3, on: statement)
                try Self.bindDouble(updatedAt.timeIntervalSince1970, at: 4, on: statement)
            }
        )
    }

    private func refreshConversationSummary(for conversationID: UUID, updatedAt: Date?) throws {
        let messages = try loadMessageRecords(for: conversationID)
        let lastMessage = messages.last

        _ = try execute(
            """
            UPDATE conversations
            SET message_count = ?,
                last_message_at = ?,
                last_message_preview = ?
            WHERE id = ?
            """,
            bind: { statement in
                try Self.bindInt64(Int64(messages.count), at: 1, on: statement)
                try Self.bindOptionalDouble(lastMessage?.date.timeIntervalSince1970, at: 2, on: statement)
                try Self.bindOptionalText(lastMessage?.text, at: 3, on: statement)
                try Self.bindUUID(conversationID, at: 4, on: statement)
            }
        )

        try refreshSearchTerms(for: conversationID, updatedAt: updatedAt)
    }

    private func refreshSearchTerms(for conversationID: UUID, updatedAt: Date?) throws {
        let conversation = try loadConversationRecord(id: conversationID)
        let messages = try loadMessageRecords(for: conversationID)
        let searchableText = ([conversation?.title ?? ""] + messages.map(\.text)).joined(separator: "\n")
        let tokens = Self.tokenize(searchableText)

        _ = try execute(
            "DELETE FROM conversation_search_terms WHERE conversation_id = ?",
            bind: { statement in
                try Self.bindUUID(conversationID, at: 1, on: statement)
            }
        )

        for token in tokens {
            _ = try execute(
                """
                INSERT OR IGNORE INTO conversation_search_terms (conversation_id, term)
                VALUES (?, ?)
                """,
                bind: { statement in
                    try Self.bindUUID(conversationID, at: 1, on: statement)
                    try Self.bindText(token, at: 2, on: statement)
                }
            )
        }

        if let updatedAt {
            _ = try execute(
                "UPDATE conversations SET updated_at = ? WHERE id = ?",
                bind: { statement in
                    try Self.bindDouble(updatedAt.timeIntervalSince1970, at: 1, on: statement)
                    try Self.bindUUID(conversationID, at: 2, on: statement)
                }
            )
        }
    }

    private func loadConversationRecord(id: UUID) throws -> ConversationRecord? {
        try fetchConversationRecord(
            sql: """
            SELECT
                id,
                title,
                title_origin,
                selected_model_id,
                selected_model_name,
                selected_model_path,
                created_at,
                updated_at
            FROM conversations
            WHERE id = ?
            LIMIT 1
            """,
            bind: { statement in
                try Self.bindUUID(id, at: 1, on: statement)
            }
        )
    }

    private func loadMessageRecords(for conversationID: UUID) throws -> [MessageRecord] {
        try fetchMessageRecords(
            sql: """
            SELECT id, conversation_id, role, text, date
            FROM messages
            WHERE conversation_id = ?
            ORDER BY date ASC, rowid ASC
            """,
            bind: { statement in
                try Self.bindUUID(conversationID, at: 1, on: statement)
            }
        )
    }

    private func conversationExists(id: UUID) throws -> Bool {
        try loadConversationRecord(id: id) != nil
    }

    private func openDatabase() throws {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK, let database else {
            if let database {
                sqlite3_close_v2(database)
            }
            throw SQLiteStorageError.failedToOpenDatabase(databaseURL)
        }

        self.database = database
    }

    private func configureDatabase() throws {
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")
        try execute("PRAGMA busy_timeout = 5000")
    }

    private func installSchemaIfNeeded() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS schema_info (
                name TEXT PRIMARY KEY NOT NULL,
                value INTEGER NOT NULL
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT,
                title_origin TEXT NOT NULL DEFAULT 'manual',
                selected_model_id TEXT,
                selected_model_name TEXT,
                selected_model_path TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                message_count INTEGER NOT NULL DEFAULT 0,
                last_message_at REAL,
                last_message_preview TEXT
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY NOT NULL,
                conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                role TEXT NOT NULL,
                text TEXT NOT NULL,
                date REAL NOT NULL
            )
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS conversation_search_terms (
                conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
                term TEXT NOT NULL,
                PRIMARY KEY (conversation_id, term)
            )
            """
        )

        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations(updated_at DESC)")
        try execute("CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations(last_message_at DESC)")
        try execute("CREATE INDEX IF NOT EXISTS idx_messages_conversation_date ON messages(conversation_id, date)")
        try execute("CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date)")
        try execute("CREATE INDEX IF NOT EXISTS idx_conversation_search_terms_term ON conversation_search_terms(term)")

        try migrateConversationTitleOriginIfNeeded()

        let version = try currentSchemaVersion()
        if version < Schema.version {
            _ = try execute(
                """
                INSERT INTO schema_info (name, value)
                VALUES ('schema_version', ?)
                ON CONFLICT(name) DO UPDATE SET value = excluded.value
                """,
                bind: { statement in
                    try Self.bindInt64(Schema.version, at: 1, on: statement)
                }
            )
        }
    }

    private func currentSchemaVersion() throws -> Int64 {
        let rows = try fetchInt64s(sql: "SELECT value FROM schema_info WHERE name = 'schema_version' LIMIT 1")
        return rows.first ?? 0
    }

    private func migrateConversationTitleOriginIfNeeded() throws {
        guard try !conversationTableHasColumn(named: "title_origin") else {
            return
        }

        try execute("ALTER TABLE conversations ADD COLUMN title_origin TEXT NOT NULL DEFAULT 'manual'")
        _ = try execute(
            """
            UPDATE conversations
            SET title_origin = 'autoGenerated'
            WHERE title IS NOT NULL AND TRIM(title) != ''
            """
        )
    }

    private func conversationTableHasColumn(named column: String) throws -> Bool {
        try fetchRows(
            sql: "PRAGMA table_info(conversations)",
            map: { statement in
                Self.readOptionalText(from: statement, column: 1)
            }
        ).compactMap { $0 }.contains(column)
    }

    private func fetchConversations(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> [Conversation] {
        try fetchConversationRecords(sql: sql, bind: bind).map { Self.makeConversation(from: $0) }
    }

    private func fetchConversation(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> Conversation? {
        try fetchConversationRecord(sql: sql, bind: bind).map { Self.makeConversation(from: $0) }
    }

    private func fetchConversationRecords(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> [ConversationRecord] {
        try fetchRows(sql: sql, bind: bind, map: { try Self.readConversationRecord(from: $0) })
    }

    private func fetchConversationRecord(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> ConversationRecord? {
        try fetchRows(sql: sql, bind: bind, map: { try Self.readConversationRecord(from: $0) }).first
    }

    private func fetchMessageRecords(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> [MessageRecord] {
        try fetchRows(sql: sql, bind: bind, map: { try Self.readMessageRecord(from: $0) })
    }

    private func fetchMessages(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> [Message] {
        try fetchMessageRecords(sql: sql, bind: bind).map { Self.makeMessage(from: $0) }
    }

    private func fetchInt64s(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil) throws -> [Int64] {
        try fetchRows(sql: sql, bind: bind) { statement in
            sqlite3_column_int64(statement, 0)
        }
    }

    private func fetchRows<T>(sql: String, bind: ((OpaquePointer) throws -> Void)? = nil, map: (OpaquePointer) throws -> T) throws -> [T] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        if let bind {
            try bind(statement)
        }

        var results: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                results.append(try map(statement))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw SQLiteStorageError.failedToExecuteStatement(Self.lastErrorMessage(database))
            }
        }

        return results
    }

    private struct ConversationRecord {
        let id: UUID
        let title: String?
        let titleOrigin: ConversationTitleOrigin
        let selectedModel: LLMModel?
        let createdAt: Date
        let updatedAt: Date
    }

    private struct MessageRecord {
        let id: UUID
        let conversationID: UUID
        let role: Message.Role
        let text: String
        let date: Date
    }

    private static func readConversationRecord(from statement: OpaquePointer) throws -> ConversationRecord {
        guard
            let id = readUUID(from: statement, column: 0),
            let createdAt = readDate(from: statement, column: 6),
            let updatedAt = readDate(from: statement, column: 7)
        else {
            throw SQLiteStorageError.invalidRow
        }

        let title = readOptionalText(from: statement, column: 1)
        let titleOriginRaw = readOptionalText(from: statement, column: 2)
        let selectedModelID = readOptionalText(from: statement, column: 3)
        let selectedModelName = readOptionalText(from: statement, column: 4)
        let selectedModel: LLMModel?
        if let selectedModelID, let selectedModelName {
            selectedModel = LLMModel(id: selectedModelID, name: selectedModelName)
        } else {
            selectedModel = nil
        }

        let titleOrigin = ConversationTitleOrigin(rawValue: titleOriginRaw ?? ConversationTitleOrigin.manual.rawValue) ?? .manual

        return ConversationRecord(
            id: id,
            title: title,
            titleOrigin: titleOrigin,
            selectedModel: selectedModel,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func readMessageRecord(from statement: OpaquePointer) throws -> MessageRecord {
        guard
            let id = readUUID(from: statement, column: 0),
            let conversationID = readUUID(from: statement, column: 1),
            let roleRaw = readOptionalText(from: statement, column: 2),
            let role = Message.Role(rawValue: roleRaw),
            let date = readDate(from: statement, column: 4)
        else {
            throw SQLiteStorageError.invalidRow
        }

        let text = readOptionalText(from: statement, column: 3) ?? ""
        return MessageRecord(id: id, conversationID: conversationID, role: role, text: text, date: date)
    }

    private static func makeConversation(from record: ConversationRecord) -> Conversation {
        Conversation(
            id: record.id,
            title: record.title,
            titleOrigin: record.titleOrigin,
            messages: [],
            selectedModel: record.selectedModel,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func makeMessage(from record: MessageRecord) -> Message {
        Message(id: record.id, role: record.role, text: record.text, date: record.date)
    }

    private static func bindUUID(_ uuid: UUID, at index: Int32, on statement: OpaquePointer) throws {
        try bindText(uuid.uuidString, at: index, on: statement)
    }

    private static func bindText(_ text: String, at index: Int32, on statement: OpaquePointer) throws {
        let result = text.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, sqliteTransient)
        }
        guard result == SQLITE_OK else {
            throw SQLiteStorageError.failedToBindParameter(lastErrorMessage(nil))
        }
    }

    private static func bindOptionalText(_ text: String?, at index: Int32, on statement: OpaquePointer) throws {
        guard let text else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteStorageError.failedToBindParameter(lastErrorMessage(nil))
            }
            return
        }
        try bindText(text, at: index, on: statement)
    }

    private static func bindDouble(_ value: Double, at index: Int32, on statement: OpaquePointer) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SQLiteStorageError.failedToBindParameter(lastErrorMessage(nil))
        }
    }

    private static func bindOptionalDouble(_ value: Double?, at index: Int32, on statement: OpaquePointer) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteStorageError.failedToBindParameter(lastErrorMessage(nil))
            }
            return
        }
        try bindDouble(value, at: index, on: statement)
    }

    private static func bindInt64(_ value: Int64, at index: Int32, on statement: OpaquePointer) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw SQLiteStorageError.failedToBindParameter(lastErrorMessage(nil))
        }
    }

    private static func readUUID(from statement: OpaquePointer, column: Int32) -> UUID? {
        guard let text = readOptionalText(from: statement, column: column) else {
            return nil
        }
        return UUID(uuidString: text)
    }

    private static func readOptionalText(from statement: OpaquePointer, column: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(decodingCString: cString, as: UTF8.self)
    }

    private static func readDate(from statement: OpaquePointer, column: Int32) -> Date? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
    }

    private static func lastErrorMessage(_ database: OpaquePointer?) -> String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }

    private static func ensureDirectoryExists(at url: URL, fileManager: FileManager) throws {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw SQLiteStorageError.failedToCreateDirectory(url, underlying: error)
            }
        }
    }

    private static func tokenize(_ text: String) -> [String] {
        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ).lowercased()

        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(tokens)).sorted()
    }
}
