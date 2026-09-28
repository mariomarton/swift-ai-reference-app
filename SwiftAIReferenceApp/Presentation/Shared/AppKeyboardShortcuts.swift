import Foundation
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
    private static var shouldAvoidSystemReservedMacShortcuts: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #elseif os(iOS)
        ProcessInfo.processInfo.isiOSAppOnMac
        #else
        false
        #endif
    }

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
        let modifierDisplay = shouldAvoidSystemReservedMacShortcuts ? "⌘⇧" : "⌘"
        let modifiers: EventModifiers = shouldAvoidSystemReservedMacShortcuts ? [.command, .shift] : .command

        AppKeyboardShortcutDefinition(
            id: "new-conversation",
            title: L10n.KeyboardShortcuts.newConversationAction,
            keyDisplay: "N",
            modifierDisplay: modifierDisplay,
            keyEquivalent: "n",
            modifiers: modifiers
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
        let modifierDisplay = shouldAvoidSystemReservedMacShortcuts ? "⌘⇧" : "⌘"
        let modifiers: EventModifiers = shouldAvoidSystemReservedMacShortcuts ? [.command, .shift] : .command

        AppKeyboardShortcutDefinition(
            id: "open-settings",
            title: L10n.KeyboardShortcuts.openSettingsAction,
            keyDisplay: ",",
            modifierDisplay: modifierDisplay,
            keyEquivalent: ",",
            modifiers: modifiers
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
