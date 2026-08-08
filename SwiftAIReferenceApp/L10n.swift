import Foundation

// MARK: - Localization

/// Central namespace for all user-visible strings.
///
/// Strings are resolved from localized `.strings` files, with `en.lproj` as the
/// source language and `cs.lproj` / `sk.lproj` providing overrides.
enum L10n {

    enum App {
        static var previewUnavailable: String { l("app.preview.unavailable") }
        static var failedToStartTitle: String { l("app.launch.failedTitle") }
    }

    enum Chat {
        static var emptyStateTitle: String { l("chat.emptyState.title") }
        static var emptyStateDescription: String { l("chat.emptyState.description") }
        static var sendingIndicator: String { l("chat.sendingIndicator") }
        static var backgroundInterruptedMessage: String { l("chat.backgroundInterrupted.message") }
        static var interruptedByNewConversationMessage: String { l("chat.interruptedByNewConversation.message") }
        static var generationConflictMessage: String { l("chat.generationConflict.message") }
        static var generationConflictWaitAction: String { l("chat.generationConflict.waitAction") }
        static var generationConflictStopAndSendAction: String { l("chat.generationConflict.stopAndSendAction") }
        static var stopAction: String { l("chat.stopAction") }
        static var userStoppedGenerationMessage: String { l("chat.userStoppedGeneration.message") }
        static var navigationTitle: String { l("chat.navigationTitle") }
        static var openSidebarLabel: String { l("chat.openSidebar.label") }
        static var searchConversationsLabel: String { l("chat.searchConversations.label") }
        static var loading: String { l("chat.loading") }
        static var errorLoadTitle: String { l("chat.error.load.title") }
        static var errorSendTitle: String { l("chat.error.send.title") }
        static var errorRefreshTitle: String { l("chat.error.refresh.title") }
    }

    enum ConversationsList {
        static var emptyStateTitle: String { l("conversations.emptyState.title") }
        static var emptyStateDescription: String { l("conversations.emptyState.description") }
        static var searchPrompt: String { l("conversations.search.prompt") }
        static var searchEmptyTitle: String { l("conversations.search.empty.title") }
        static var searchEmptyDescription: String { l("conversations.search.empty.description") }
        static var navigationTitle: String { l("conversations.navigationTitle") }
        static var newConversationLabel: String { l("conversations.newButton.label") }
        static var generatingStatus: String { l("conversations.generating.status") }
        static var loading: String { l("conversations.loading") }
        static var defaultConversationTitle: String { l("conversations.defaultTitle") }
        static var errorLoadTitle: String { l("conversations.error.load.title") }
        static var errorCreateTitle: String { l("conversations.error.create.title") }
        static var errorDeleteTitle: String { l("conversations.error.delete.title") }
        static var errorRenameTitle: String { l("conversations.error.rename.title") }
        static var deleteAction: String { l("conversations.action.delete") }
        static var renameAction: String { l("conversations.action.rename") }
        static var renameTitle: String { l("conversations.rename.title") }
        static var renamePlaceholder: String { l("conversations.rename.placeholder") }
        static var renameSaveAction: String { l("conversations.rename.saveAction") }
    }

    enum Common {
        static var retry: String { l("common.retry") }
        static var cancel: String { l("common.cancel") }
        static var ok: String { l("common.ok") }
    }

    enum Composer {
        static var placeholder: String { l("composer.placeholder") }
        static var stopAccessibilityLabel: String { l("composer.stop.accessibilityLabel") }
        static var sendAccessibilityLabel: String { l("composer.send.accessibilityLabel") }
    }

    enum Settings {
        static var navigationTitle: String { l("settings.navigationTitle") }
        static var accentColorTitle: String { l("settings.accentColor.title") }
        static var accentColorFooter: String { l("settings.accentColor.footer") }
        static var accentColorOrange: String { l("settings.accentColor.orange") }
        static var accentColorBlue: String { l("settings.accentColor.blue") }
        static var accentColorIndigo: String { l("settings.accentColor.indigo") }
        static var accentColorPurple: String { l("settings.accentColor.purple") }
        static var accentColorTeal: String { l("settings.accentColor.teal") }
        static var accentColorGreen: String { l("settings.accentColor.green") }
        static var accentColorRed: String { l("settings.accentColor.red") }
        static var modeTitle: String { l("settings.mode.title") }
        static var modeFooter: String { l("settings.mode.footer") }
        static var modeNone: String { l("settings.mode.none") }
        static var modeConcise: String { l("settings.mode.concise") }
        static var modeFriendly: String { l("settings.mode.friendly") }
        static var modeHumorous: String { l("settings.mode.humorous") }
        static var systemPromptTitle: String { l("settings.systemPrompt.title") }
        static var systemPromptFooter: String { l("settings.systemPrompt.footer") }
        static var systemPromptAction: String { l("settings.systemPrompt.action") }
        static var customInstructionsTitle: String { l("settings.customInstructions.title") }
        static var customInstructionsFooter: String { l("settings.customInstructions.footer") }
        static var resetAction: String { l("settings.reset.action") }
    }

    enum MessageActions {
        static var copy: String { l("message.action.copy") }
    }

    enum StubLLMEngine {
        static var responsePrefix: String { l("stubLLMEngine.responsePrefix") }
        static var fallbackResponse: String { l("stubLLMEngine.fallbackResponse") }
    }

    enum Errors {
        static var repositoryError: String { l("error.repository") }
        static var engineError: String { l("error.engine") }
        static var invalidModel: String { l("error.invalidModel") }
        static var invalidConversationTitle: String { l("error.invalidConversationTitle") }
        static var conversationNotFound: String { l("error.conversationNotFound") }
        static var unknown: String { l("error.unknown") }
    }

    enum AppDependencies {
        static var startupWarningMissingModel: String {
            l("app.dependencies.startupWarningMissingModel")
        }

        static var startupWarningModelLoadFailed: String {
            l("app.dependencies.startupWarningModelLoadFailed")
        }
    }

    enum PromptSettings {
        static var defaultSystemPrompt: String {
            l("prompt.defaultSystemPrompt")
        }

        static var toneConcise: String {
            l("prompt.tone.concise")
        }

        static var toneFriendly: String {
            l("prompt.tone.friendly")
        }

        static var toneHumorous: String {
            l("prompt.tone.humorous")
        }
    }

    enum Llama {
        static func modelNotFound(path: String) -> String {
            lf("llama.modelNotFound", path)
        }

        static var modelLoadFailed: String {
            l("llama.modelLoadFailed")
        }

        static func unsupportedModelArchitecture(description: String) -> String {
            lf("llama.unsupportedModelArchitecture", description)
        }

        static var contextCreationFailed: String {
            l("llama.contextCreationFailed")
        }

        static var tokenizationFailed: String {
            l("llama.tokenizationFailed")
        }

        static func inferenceFailed(_ underlyingDescription: String) -> String {
            lf("llama.inferenceFailed", underlyingDescription)
        }
    }
}

private func l(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func lf(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: l(key), arguments: arguments)
}
