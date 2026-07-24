import Foundation

enum AppDependenciesError: LocalizedError {
    case storageInitializationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .storageInitializationFailed(let underlying):
            return "Failed to initialize storage: \(underlying.localizedDescription)"
        }
    }
}

final class AppDependencies {
    enum StorageBackend {
        case fileBacked
        case sqlite
    }

    let conversationRepository: ConversationRepository
    let messageRepository: MessageRepository
    let promptSettingsRepository: PromptSettingsRepository
    let searchConversationsUseCase: SearchConversationsUseCase
    let llmEngine: LLMEngine
    let startupWarning: String?

    let loadConversationsUseCase: LoadConversationsUseCase
    let deleteConversationUseCase: DeleteConversationUseCase
    let loadRecentMessagesUseCase: LoadRecentMessagesUseCase
    let sendMessageUseCase: SendMessageUseCase
    let messageGenerationCoordinator: MessageGenerationCoordinator

    init(
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository,
        promptSettingsRepository: PromptSettingsRepository,
        llmEngine: LLMEngine,
        startupWarning: String? = nil
    ) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.promptSettingsRepository = promptSettingsRepository
        self.searchConversationsUseCase = DefaultSearchConversationsUseCase()
        self.llmEngine = llmEngine
        self.startupWarning = startupWarning

        self.loadConversationsUseCase = DefaultLoadConversationsUseCase(repository: conversationRepository)
        self.deleteConversationUseCase = DefaultDeleteConversationUseCase(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository
        )
        self.loadRecentMessagesUseCase = DefaultLoadRecentMessagesUseCase(repository: messageRepository)

        let titleGenerator = LlamaConversationTitleGenerator(engine: llmEngine)
        let generateTitleUseCase = DefaultGenerateConversationTitleUseCase(generator: titleGenerator)
        self.sendMessageUseCase = DefaultSendMessageUseCase(
            repository: messageRepository,
            conversationRepository: conversationRepository,
            engine: llmEngine,
            promptSettingsRepository: promptSettingsRepository,
            generateTitleUseCase: generateTitleUseCase
        )
        self.messageGenerationCoordinator = MessageGenerationCoordinator(
            sendMessageUseCase: self.sendMessageUseCase
        )
    }

    convenience init() throws {
        try self.init(storageBackend: Self.resolveStorageBackend())
    }

    convenience init(storageBackend: StorageBackend) throws {
        let (conversationRepository, messageRepository) = try Self.makeStorageRepositories(for: storageBackend)
        let promptSettingsRepository = UserDefaultsPromptSettingsRepository()
        let (llmEngine, startupWarning) = Self.makeLLMEngine(
            modelPath: Self.resolveModelPath(resourceURL: Bundle.main.resourceURL)
        )

        self.init(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            promptSettingsRepository: promptSettingsRepository,
            llmEngine: llmEngine,
            startupWarning: startupWarning
        )
    }

    private static func resolveStorageBackend() -> StorageBackend {
        let rawValue = ProcessInfo.processInfo.environment["SWIFTAIREFERENCEAPP_STORAGE_BACKEND"]?.lowercased()
        switch rawValue {
        case "file", "filebacked":
            return .fileBacked
        default:
            return .sqlite
        }
    }

    private static func makeStorageRepositories(for backend: StorageBackend) throws -> (ConversationRepository, MessageRepository) {
        switch backend {
        case .fileBacked:
            return (try FileBackedConversationRepository(), try FileBackedMessageRepository())
        case .sqlite:
            do {
                let store = try SQLiteConversationMessageStore()
                return (SQLiteConversationRepository(store: store), SQLiteMessageRepository(store: store))
            } catch {
                throw AppDependenciesError.storageInitializationFailed(underlying: error)
            }
        }
    }

    static func resolveModelPath(
        resourceURL: URL?,
        fileManager: FileManager = .default
    ) -> String? {
        guard let resourceURL else { return nil }

        let bundledExact = resourceURL.appendingPathComponent("model.gguf")
        if fileManager.fileExists(atPath: bundledExact.path) {
            return bundledExact.path
        }

        if let urls = try? fileManager.contentsOfDirectory(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ),
        let anyGGUF = urls.first(where: { $0.pathExtension.lowercased() == "gguf" }) {
            return anyGGUF.path
        }

        return nil
    }

    static func makeLLMEngine(
        modelPath: String?,
        isSimulator: Bool = {
            #if targetEnvironment(simulator)
            true
            #else
            false
            #endif
        }(),
        isRunningTests: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
        engineFactory: (String) throws -> LLMEngine = { try LlamaLLMEngine(modelPath: $0) }
    ) -> (LLMEngine, String?) {
        guard let modelPath else {
            return (StubLLMEngine(), L10n.AppDependencies.startupWarningMissingModel)
        }

        if isSimulator || isRunningTests {
            return (StubLLMEngine(), nil)
        }

        do {
            return (try engineFactory(modelPath), nil)
        } catch {
            return (StubLLMEngine(), L10n.AppDependencies.startupWarningModelLoadFailed)
        }
    }

    @MainActor
    func makeConversationsListViewModel() -> ConversationsListViewModel {
        ConversationsListViewModel(
            loadConversationsUseCase: loadConversationsUseCase,
            loadRecentMessagesUseCase: loadRecentMessagesUseCase,
            searchConversationsUseCase: searchConversationsUseCase,
            deleteConversationUseCase: deleteConversationUseCase,
            generationCoordinator: messageGenerationCoordinator
        )
    }

    @MainActor
    func makeChatViewModel(conversationID: UUID) -> ChatViewModel {
        ChatViewModel(
            conversationID: conversationID,
            loadRecentMessagesUseCase: loadRecentMessagesUseCase,
            generationCoordinator: messageGenerationCoordinator
        )
    }

    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(repository: promptSettingsRepository)
    }
}
