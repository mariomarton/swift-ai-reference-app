import SwiftUI

struct SystemPromptEditorView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                TextEditor(text: $viewModel.systemPrompt)
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
            } footer: {
                Text(L10n.Settings.systemPromptFooter)
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
            }
        }
        .navigationTitle(L10n.Settings.systemPromptTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
