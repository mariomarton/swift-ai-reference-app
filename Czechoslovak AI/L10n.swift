import Foundation

// MARK: - Localization

/// Central namespace for all user-visible strings.
///
/// English is the built-in source language; localized `.strings` files can override
/// the defaults for Slovak and Czech.
enum L10n {

    enum App {
        static var previewUnavailable: String { l("app.preview.unavailable", "Preview unavailable") }
        static var failedToStartTitle: String { l("app.launch.failedTitle", "App Failed to Start") }
    }

    enum Chat {
        static var emptyStateTitle: String { l("chat.emptyState.title", "No messages yet") }
        static var emptyStateDescription: String { l("chat.emptyState.description", "Send the first message to start the conversation.") }
        static var sendingIndicator: String { l("chat.sendingIndicator", "Assistant is thinking...") }
        static var backgroundInterruptedMessage: String { l("chat.backgroundInterrupted.message", "Generation was interrupted after the app was sent to the background.") }
        static var interruptedByNewConversationMessage: String { l("chat.interruptedByNewConversation.message", "Generation stopped because you started a new reply in another chat.") }
        static var generationConflictMessage: String { l("chat.generationConflict.message", "Generation is already in progress in another chat. Wait for it to finish or stop it.") }
        static var generationConflictWaitAction: String { l("chat.generationConflict.waitAction", "Wait") }
        static var generationConflictStopAndSendAction: String { l("chat.generationConflict.stopAndSendAction", "Stop and continue here") }
        static var stopAction: String { l("chat.stopAction", "Stop") }
        static var userStoppedGenerationMessage: String { l("chat.userStoppedGeneration.message", "Generation was stopped by the user.") }
        static var navigationTitle: String { l("chat.navigationTitle", "Chat") }
        static var openSidebarLabel: String { l("chat.openSidebar.label", "Open conversations") }
        static var searchConversationsLabel: String { l("chat.searchConversations.label", "Search conversations") }
        static var loading: String { l("chat.loading", "Loading messages") }
        static var errorLoadTitle: String { l("chat.error.load.title", "Could not load messages") }
        static var errorSendTitle: String { l("chat.error.send.title", "Could not send message") }
        static var errorRefreshTitle: String { l("chat.error.refresh.title", "Could not refresh messages") }
    }

    enum ConversationsList {
        static var emptyStateTitle: String { l("conversations.emptyState.title", "No conversations yet") }
        static var emptyStateDescription: String { l("conversations.emptyState.description", "Create your first conversation and start chatting.") }
        static var searchPrompt: String { l("conversations.search.prompt", "Search conversations") }
        static var searchEmptyTitle: String { l("conversations.search.empty.title", "No results found") }
        static var searchEmptyDescription: String { l("conversations.search.empty.description", "Try a different conversation name or message.") }
        static var navigationTitle: String { l("conversations.navigationTitle", "Conversations") }
        static var newConversationLabel: String { l("conversations.newButton.label", "New conversation") }
        static var generatingStatus: String { l("conversations.generating.status", "Generating...") }
        static var loading: String { l("conversations.loading", "Loading...") }
        static var defaultConversationTitle: String { l("conversations.defaultTitle", "New chat") }
        static var errorLoadTitle: String { l("conversations.error.load.title", "Could not load conversations") }
        static var errorCreateTitle: String { l("conversations.error.create.title", "Could not create conversation") }
        static var errorDeleteTitle: String { l("conversations.error.delete.title", "Could not delete conversation") }
        static var deleteAction: String { l("conversations.action.delete", "Delete") }
    }

    enum Common {
        static var retry: String { l("common.retry", "Retry") }
        static var cancel: String { l("common.cancel", "Cancel") }
        static var ok: String { l("common.ok", "OK") }
    }

    enum Composer {
        static var placeholder: String { l("composer.placeholder", "Type your message") }
        static var stopAccessibilityLabel: String { l("composer.stop.accessibilityLabel", "Stop generation") }
        static var sendAccessibilityLabel: String { l("composer.send.accessibilityLabel", "Send message") }
    }

    enum Settings {
        static var navigationTitle: String { l("settings.navigationTitle", "Settings") }
        static var modeTitle: String { l("settings.mode.title", "Response style") }
        static var modeFooter: String { l("settings.mode.footer", "The style adds a short instruction to the system prompt.") }
        static var modeNone: String { l("settings.mode.none", "No style") }
        static var modeConcise: String { l("settings.mode.concise", "Concise") }
        static var modeFriendly: String { l("settings.mode.friendly", "Friendly") }
        static var modeHumorous: String { l("settings.mode.humorous", "Humorous") }
        static var systemPromptTitle: String { l("settings.systemPrompt.title", "System prompt") }
        static var systemPromptFooter: String { l("settings.systemPrompt.footer", "This prompt will be used for all new messages.") }
        static var customInstructionsTitle: String { l("settings.customInstructions.title", "Additional instructions") }
        static var customInstructionsFooter: String { l("settings.customInstructions.footer", "Use this for style, limits, or reply preferences.") }
        static var resetAction: String { l("settings.reset.action", "Restore defaults") }
    }

    enum MessageActions {
        static var copy: String { l("message.action.copy", "Copy") }
    }

    enum Errors {
        static var repositoryError: String { l("error.repository", "Repository error") }
        static var engineError: String { l("error.engine", "Language model error") }
        static var invalidModel: String { l("error.invalidModel", "Invalid or unsupported model") }
        static var unknown: String { l("error.unknown", "An unknown error occurred") }
    }

    enum AppDependencies {
        static var modelNotConfigured: String {
            l(
                "app.dependencies.modelNotConfigured",
                "No GGUF model was found. Provide a bundled .gguf model or set LLAMA_MODEL_PATH in your Run scheme environment."
            )
        }

        static func llamaInitializationFailed(_ underlyingDescription: String) -> String {
            lf(
                "app.dependencies.llamaInitializationFailed",
                "Failed to initialize local LLM: %@",
                underlyingDescription
            )
        }
    }

    enum PromptSettings {
        static var defaultSystemPrompt: String {
            l("prompt.defaultSystemPrompt", "You are a helpful assistant. Answer clearly and concisely.")
        }

        static var toneConcise: String {
            l("prompt.tone.concise", "Answer briefly and directly.")
        }

        static var toneFriendly: String {
            l("prompt.tone.friendly", "Use a warm, friendly tone.")
        }

        static var toneHumorous: String {
            l("prompt.tone.humorous", "Add light, tasteful humor when appropriate.")
        }
    }

    enum Llama {
        static func modelNotFound(path: String) -> String {
            lf("llama.modelNotFound", "Model file not found at path: %@", path)
        }

        static var modelLoadFailed: String {
            l("llama.modelLoadFailed", "Failed to load model - the file may be corrupted or in an unsupported format.")
        }

        static func unsupportedModelArchitecture(description: String) -> String {
            lf(
                "llama.unsupportedModelArchitecture",
                "Unsupported model architecture: %@. Use a decoder-only instruct/chat GGUF model.",
                description
            )
        }

        static var contextCreationFailed: String {
            l("llama.contextCreationFailed", "Failed to create inference context - the device may not have enough memory.")
        }

        static var tokenizationFailed: String {
            l("llama.tokenizationFailed", "Failed to tokenize the input prompt.")
        }

        static func inferenceFailed(_ underlyingDescription: String) -> String {
            lf("llama.inferenceFailed", "Inference failed: %@", underlyingDescription)
        }
    }
}

// Short helper to avoid repeating NSLocalizedString boilerplate throughout the enum.
private func l(_ key: String, _ defaultValue: String) -> String {
    NSLocalizedString(key, value: defaultValue, comment: "")
}

private func lf(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
    String(format: l(key, defaultValue), arguments: arguments)
}
