import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.Settings.accentColorTitle, selection: $viewModel.accentColor) {
                    ForEach(PromptAccentColor.allCases) { accentColor in
                        AccentColorPickerRow(
                            title: accentColor.localizedTitle,
                            color: accentColor.color
                        )
                        .tag(accentColor)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text(L10n.Settings.accentColorFooter)
            }

            Section {
                Picker(L10n.Settings.modeTitle, selection: $viewModel.tonePreset) {
                    ForEach(PromptTonePreset.allCases) { preset in
                        Text(label(for: preset)).tag(preset)
                    }
                }
                .id(viewModel.responseStylePickerIdentity)
            } footer: {
                Text(L10n.Settings.modeFooter)
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
                NavigationLink {
                    SystemPromptEditorView(viewModel: viewModel)
                } label: {
                    Label {
                        Text(L10n.Settings.systemPromptAction)
                    } icon: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.Settings.systemPromptTitle)
            } footer: {
                Text(L10n.Settings.systemPromptFooter)
                    .foregroundStyle(.red)
                    .fontWeight(.semibold)
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
        .tint(viewModel.accentColor.color)
        .onChange(of: viewModel.systemPrompt) { _, _ in viewModel.save() }
        .onChange(of: viewModel.customInstructions) { _, _ in viewModel.save() }
        .onChange(of: viewModel.tonePreset) { _, _ in viewModel.save() }
        .onChange(of: viewModel.accentColor) { _, _ in viewModel.save() }
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

private struct AccentColorPickerRow: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                }

            Text(title)
        }
    }
}
