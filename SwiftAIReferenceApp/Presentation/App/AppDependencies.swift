import Foundation

enum AppDependenciesError: LocalizedError {
    case modelNotConfigured
    case llamaInitializationFailed(underlying: Error)
    case storageInitializationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .modelNotConfigured:
            return L10n.AppDependencies.modelNotConfigured
        case .llamaInitializationFailed(let underlying):
            return L10n.AppDependencies.llamaInitializationFailed(underlying.localizedDescription)
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

    let loadConversationsUseCase: LoadConversationsUseCase
    let deleteConversationUseCase: DeleteConversationUseCase
    let loadRecentMessagesUseCase: LoadRecentMessagesUseCase
    let sendMessageUseCase: SendMessageUseCase
    let messageGenerationCoordinator: MessageGenerationCoordinator

    init(
        conversationRepository: ConversationRepository,
        messageRepository: MessageRepository,
        promptSettingsRepository: PromptSettingsRepository,
        llmEngine: LLMEngine
    ) {
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.promptSettingsRepository = promptSettingsRepository
        self.searchConversationsUseCase = DefaultSearchConversationsUseCase()
        self.llmEngine = llmEngine

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
        let llmEngine: LLMEngine

        #if targetEnvironment(simulator)
        // llama.cpp Metal backend is not stable on iOS Simulator runtimes.
        // Use the stub engine in Simulator; real on-device builds still use llama.
        llmEngine = StubLLMEngine()
        #else

        // When running under XCTest (including Mac Catalyst test runs), skip the real
        // Metal-backed engine entirely. Loading it during tests initializes the Metal
        // device, whose C++ static destructor crashes on process exit — even after all
        // tests pass. XCTestConfigurationFilePath is always set by the XCTest runner.
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isRunningTests {
            llmEngine = StubLLMEngine()
        } else {
            guard let modelPath = Self.resolveModelPath() else {
                throw AppDependenciesError.modelNotConfigured
            }

            do {
                llmEngine = try LlamaLLMEngine(modelPath: modelPath)
            } catch {
                throw AppDependenciesError.llamaInitializationFailed(underlying: error)
            }
        }
        #endif

        self.init(
            conversationRepository: conversationRepository,
            messageRepository: messageRepository,
            promptSettingsRepository: promptSettingsRepository,
            llmEngine: llmEngine
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

    private static func resolveModelPath() -> String? {
        let fm = FileManager.default

        if let envPath = ProcessInfo.processInfo.environment["LLAMA_MODEL_PATH"],
           !envPath.isEmpty,
           fm.fileExists(atPath: envPath) {
            return envPath
        }

        if let bundledExact = Bundle.main.url(forResource: "model", withExtension: "gguf")?.path,
           fm.fileExists(atPath: bundledExact) {
            return bundledExact
        }

        if let resourcesURL = Bundle.main.resourceURL,
           let urls = try? fm.contentsOfDirectory(
                at: resourcesURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
           ) {
            if let anyGGUF = urls.first(where: { $0.pathExtension.lowercased() == "gguf" }) {
                return anyGGUF.path
            }
        }

        return nil
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
