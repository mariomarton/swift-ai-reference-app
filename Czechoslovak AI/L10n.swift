import Foundation

// MARK: - Localization

/// Central namespace for all user-visible strings.
///
/// Each entry calls `NSLocalizedString` with a short symbolic key and a Slovak default value.
/// Slovak is the built-in default – the app works without any .strings file.
///
/// To add a new language (e.g. Czech):
///   1. In Xcode: File > New > File > Strings File, name it "Localizable", add to the app target.
///   2. In the Project editor, add the language under "Localizations".
///   3. Fill in the .strings file for that language using the keys below.

enum L10n {

    enum Chat {
        static var emptyStateTitle: String       { l("chat.emptyState.title",       "Zatiaľ bez správ") }
        static var emptyStateDescription: String { l("chat.emptyState.description", "Pošlite prvú správu a začnite konverzáciu.") }
        static var sendingIndicator: String      { l("chat.sendingIndicator",       "Asistent premýšľa...") }
        static var backgroundInterruptedMessage: String { l("chat.backgroundInterrupted.message", "Generovanie bolo prerušené po presunutí aplikácie na pozadie.") }
        static var navigationTitle: String       { l("chat.navigationTitle",        "Chat") }
        static var loading: String               { l("chat.loading",                "Načítavam správy") }
        static var errorLoadTitle: String        { l("chat.error.load.title",       "Nepodarilo sa načítať správy") }
        static var errorSendTitle: String        { l("chat.error.send.title",       "Nepodarilo sa odoslať správu") }
        static var errorRefreshTitle: String     { l("chat.error.refresh.title",    "Nepodarilo sa obnoviť správy") }
    }

    enum ConversationsList {
        static var emptyStateTitle: String          { l("conversations.emptyState.title",        "Zatiaľ žiadne konverzácie") }
        static var emptyStateDescription: String    { l("conversations.emptyState.description",  "Vytvorte prvý chat a začnite konverzáciu.") }
        static var navigationTitle: String          { l("conversations.navigationTitle",         "Konverzácie") }
        static var newConversationLabel: String     { l("conversations.newButton.label",         "Nová konverzácia") }
        static var generatingStatus: String         { l("conversations.generating.status",       "Generuje...") }
        static var loading: String                  { l("conversations.loading",                 "Načítavam") }
        static var defaultConversationTitle: String { l("conversations.defaultTitle",            "Nový chat") }
        static var errorLoadTitle: String           { l("conversations.error.load.title",        "Nepodarilo sa načítať konverzácie") }
        static var errorCreateTitle: String         { l("conversations.error.create.title",      "Nepodarilo sa vytvoriť konverzáciu") }
        static var errorDeleteTitle: String         { l("conversations.error.delete.title",      "Nepodarilo sa odstrániť konverzáciu") }
        static var deleteAction: String             { l("conversations.action.delete",           "Odstrániť") }
    }

    enum Common {
        static var retry: String  { l("common.retry",  "Zopakovať") }
        static var cancel: String { l("common.cancel", "Zrušiť") }
        static var ok: String     { l("common.ok",     "OK") }
    }

    enum Composer {
        static var placeholder: String { l("composer.placeholder", "Napíšte správu") }
    }

    enum MessageActions {
        static var copy: String { l("message.action.copy", "Kopírovať") }
    }

    enum Errors {
        static var repositoryError: String { l("error.repository",  "Chyba úložiska") }
        static var engineError: String     { l("error.engine",      "Chyba jazykového modelu") }
        static var invalidModel: String    { l("error.invalidModel","Neplatný alebo nepodporovaný model") }
        static var unknown: String         { l("error.unknown",     "Nastala neznáma chyba") }
    }
}

// Short helper to avoid repeating NSLocalizedString boilerplate throughout the enum.
private func l(_ key: String, _ defaultValue: String) -> String {
    NSLocalizedString(key, value: defaultValue, comment: "")
}
