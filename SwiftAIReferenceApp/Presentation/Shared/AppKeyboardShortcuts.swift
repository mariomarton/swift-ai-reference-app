import SwiftUI

struct AppKeyboardShortcutDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let keyDisplay: String
    let modifierDisplay: String
    let keyEquivalent: KeyEquivalent
    let modifiers: EventModifiers

    var displayValue: String {
        modifierDisplay + keyDisplay
    }
}

enum AppKeyboardShortcuts {
    static var sendMessage: AppKeyboardShortcutDefinition {
        AppKeyboardShortcutDefinition(
            id: "send-message",
            title: L10n.KeyboardShortcuts.sendMessageAction,
            keyDisplay: "↩",
            modifierDisplay: "",
            keyEquivalent: .return,
            modifiers: []
        )
    }

    static var newConversation: AppKeyboardShortcutDefinition {
        AppKeyboardShortcutDefinition(
            id: "new-conversation",
            title: L10n.KeyboardShortcuts.newConversationAction,
            keyDisplay: "N",
            modifierDisplay: "⌘",
            keyEquivalent: "n",
            modifiers: .command
        )
    }

    static var toggleSidebar: AppKeyboardShortcutDefinition {
        AppKeyboardShortcutDefinition(
            id: "toggle-sidebar",
            title: L10n.KeyboardShortcuts.toggleSidebarAction,
            keyDisplay: "S",
            modifierDisplay: "⌘⌥",
            keyEquivalent: "s",
            modifiers: [.command, .option]
        )
    }

    static var openSettings: AppKeyboardShortcutDefinition {
        AppKeyboardShortcutDefinition(
            id: "open-settings",
            title: L10n.KeyboardShortcuts.openSettingsAction,
            keyDisplay: ",",
            modifierDisplay: "⌘",
            keyEquivalent: ",",
            modifiers: .command
        )
    }

    static var discoverableShortcuts: [AppKeyboardShortcutDefinition] {
        [
            sendMessage,
            newConversation,
            toggleSidebar,
            openSettings
        ]
    }
}
