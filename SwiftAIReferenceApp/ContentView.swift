import SwiftUI

@MainActor
struct ContentView: View {
    private let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var conversationsViewModel: ConversationsListViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var shellViewModel = ChatShellViewModel()

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _conversationsViewModel = StateObject(wrappedValue: dependencies.makeConversationsListViewModel())
        _settingsViewModel = StateObject(wrappedValue: dependencies.makeSettingsViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            if let warning = dependencies.startupWarning {
                StartupWarningBanner(message: warning, accentColor: settingsViewModel.accentColor)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }

            Group {
                if isCompactLayout {
                    NavigationStack(path: $shellViewModel.compactPath) {
                        ConversationsListView(
                            viewModel: conversationsViewModel,
                            accentColor: settingsViewModel.accentColor,
                            showsSettingsButton: shellViewModel.shouldShowConversationsListSettingsButton(
                                isCompactLayout: isCompactLayout
                            ),
                            onSettingsTapped: {
                                shellViewModel.presentSettings()
                            }
                        )
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                case .chat(let conversationID):
                                    ChatView(
                                        viewModel: dependencies.makeChatViewModel(conversationID: conversationID),
                                        accentColor: settingsViewModel.accentColor,
                                        onNewConversationTapped: {
                                            _ = conversationsViewModel.startConversation()
                                        },
                                        onSettingsTapped: {
                                            shellViewModel.presentSettings()
                                        }
                                    )
                                case .settings:
                                    SettingsView(viewModel: settingsViewModel)
                                }
                            }
                    }
                } else {
                    NavigationSplitView(columnVisibility: $shellViewModel.columnVisibility) {
                        NavigationStack {
                            ConversationsListView(
                                viewModel: conversationsViewModel,
                                accentColor: settingsViewModel.accentColor,
                                showsSettingsButton: shellViewModel.shouldShowConversationsListSettingsButton(
                                    isCompactLayout: isCompactLayout
                                ),
                                onSettingsTapped: {
                                    shellViewModel.presentSettings()
                                }
                            )
                        }
                    } detail: {
                        NavigationStack {
                            if let conversationID = shellViewModel.activeConversationID {
                                ChatView(
                                    viewModel: dependencies.makeChatViewModel(conversationID: conversationID),
                                    accentColor: settingsViewModel.accentColor,
                                    onNewConversationTapped: {
                                        _ = conversationsViewModel.startConversation()
                                    },
                                    onSettingsTapped: {
                                        shellViewModel.presentSettings()
                                    }
                                )
                                .id(conversationID)
                            } else {
                                ContentUnavailableView(
                                    L10n.ConversationsList.emptyStateTitle,
                                    systemImage: "bubble.left.and.text.bubble.right",
                                    description: Text(L10n.ConversationsList.emptyStateDescription)
                                )
                            }
                        }
                    }
                    .navigationSplitViewStyle(.balanced)
                }
            }
        }
        .task {
            await shellViewModel.bootstrapIfNeeded(
                using: conversationsViewModel,
                isCompactLayout: isCompactLayout
            )
        }
        .onChange(of: conversationsViewModel.selectedConversationID) { _, newValue in
            guard let conversationID = newValue else { return }

            shellViewModel.handleConversationSelection(
                id: conversationID,
                isCompactLayout: isCompactLayout
            )
            conversationsViewModel.selectedConversationID = nil
        }
        .sheet(isPresented: $shellViewModel.isSettingsPresented) {
            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            dependencies.messageGenerationCoordinator.handleScenePhaseChange(newValue)
        }
        .tint(settingsViewModel.accentColor.color)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

private struct StartupWarningBanner: View {
    let message: String
    let accentColor: PromptAccentColor

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(accentColor.color)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 680, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(accentColor.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accentColor.color.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

#Preview {
    if let dependencies = try? AppDependencies() {
        ContentView(dependencies: dependencies)
    } else {
        Text(L10n.App.previewUnavailable)
    }
}
