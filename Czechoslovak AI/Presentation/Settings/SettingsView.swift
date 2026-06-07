import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.Settings.modeTitle, selection: $viewModel.tonePreset) {
                    ForEach(PromptTonePreset.allCases) { preset in
                        Text(label(for: preset)).tag(preset)
                    }
                }
            } footer: {
                Text(L10n.Settings.modeFooter)
            }

            Section {
                TextEditor(text: $viewModel.systemPrompt)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
            } header: {
                Text(L10n.Settings.systemPromptTitle)
            } footer: {
                Text(L10n.Settings.systemPromptFooter)
            }

            Section {
                TextEditor(text: $viewModel.customInstructions)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
            } header: {
                Text(L10n.Settings.customInstructionsTitle)
            } footer: {
                Text(L10n.Settings.customInstructionsFooter)
            }

            Section {
                Button(L10n.Settings.resetAction) {
                    viewModel.resetToDefaults()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle(L10n.Settings.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.systemPrompt) { _, _ in viewModel.save() }
        .onChange(of: viewModel.customInstructions) { _, _ in viewModel.save() }
        .onChange(of: viewModel.tonePreset) { _, _ in viewModel.save() }
    }

    private func label(for preset: PromptTonePreset) -> String {
        switch preset {
        case .none:
            return L10n.Settings.modeNone
        case .concise:
            return L10n.Settings.modeConcise
        case .friendly:
            return L10n.Settings.modeFriendly
        case .humorous:
            return L10n.Settings.modeHumorous
        }
    }
}
