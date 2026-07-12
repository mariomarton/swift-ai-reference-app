import SwiftUI

struct ContentView: View {
    private let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var conversationsViewModel: ConversationsListViewModel
    @StateObject private var shellViewModel = ChatShellViewModel()

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _conversationsViewModel = StateObject(wrappedValue: dependencies.makeConversationsListViewModel())
    }

    var body: some View {
        Group {
            if isCompactLayout {
                NavigationStack(path: $shellViewModel.compactPath) {
                    ConversationsListView(viewModel: conversationsViewModel)
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .chat(let conversationID):
                                ChatView(
                                    viewModel: dependencies.makeChatViewModel(conversationID: conversationID),
                                    onSearchTapped: {
                                        shellViewModel.compactPath = []
                                    },
                                    onSettingsTapped: {
                                        shellViewModel.presentSettings()
                                    }
                                )
                            case .settings:
                                SettingsView(viewModel: dependencies.makeSettingsViewModel())
                            }
                        }
                }
            } else {
                NavigationSplitView(columnVisibility: $shellViewModel.columnVisibility) {
                    NavigationStack {
                        ConversationsListView(viewModel: conversationsViewModel)
                    }
                } detail: {
                    NavigationStack {
                        if let conversationID = shellViewModel.activeConversationID {
                            ChatView(
                                viewModel: dependencies.makeChatViewModel(conversationID: conversationID),
                                onSearchTapped: {
                                    shellViewModel.showSearchInSidebar()
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
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            dependencies.messageGenerationCoordinator.handleScenePhaseChange(newValue)
        }
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }
}

#Preview {
    if let dependencies = try? AppDependencies() {
        ContentView(dependencies: dependencies)
    } else {
        Text(L10n.App.previewUnavailable)
    }
}
