import SwiftUI

struct ConversationsListView: View {
    @ObservedObject var viewModel: ConversationsListViewModel
    let accentColor: PromptAccentColor
    let onSettingsTapped: () -> Void

    var body: some View {
        List {
            Button {
                _ = viewModel.startConversation()
            } label: {
                NewConversationRowView(accentColor: accentColor)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .accessibilityIdentifier("createConversationButton")

            if viewModel.displayedConversations.isEmpty, !viewModel.isLoading {
                if viewModel.hasActiveSearch {
                    ContentUnavailableView(
                        L10n.ConversationsList.searchEmptyTitle,
                        systemImage: "magnifyingglass",
                        description: Text(L10n.ConversationsList.searchEmptyDescription)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ContentUnavailableView(
                        L10n.ConversationsList.emptyStateTitle,
                        systemImage: "bubble.left.and.text.bubble.right",
                        description: Text(L10n.ConversationsList.emptyStateDescription)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(viewModel.displayedConversations) { conversation in
                    Button {
                        viewModel.selectConversation(id: conversation.id)
                    } label: {
                        ConversationRowView(
                            conversation: conversation,
                            isGenerating: viewModel.isGenerating(conversationID: conversation.id),
                            accentColor: accentColor
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("conversation_\(conversation.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteConversation(id: conversation.id)
                            }
                        } label: {
                            Label(L10n.ConversationsList.deleteAction, systemImage: "trash")
                        }

                        Button {
                            viewModel.beginRenaming(conversation: conversation)
                        } label: {
                            Label(L10n.ConversationsList.renameAction, systemImage: "pencil")
                        }
                        .tint(accentColor.color)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .accessibilityIdentifier("conversationsList")
        .navigationTitle(L10n.ConversationsList.navigationTitle)
        .searchable(text: $viewModel.searchText, prompt: Text(L10n.ConversationsList.searchPrompt))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ConversationsListToolbarActionsView(onSettingsTapped: onSettingsTapped)
            }
        }
        .task {
            if viewModel.conversations.isEmpty {
                await viewModel.loadConversations()
            }
        }
        .onAppear {
            Task { await viewModel.loadConversations() }
        }
        .refreshable {
            await viewModel.loadConversations()
        }
        .sheet(item: $viewModel.renameConversationContext) { _ in
            NavigationStack {
                RenameConversationSheet(viewModel: viewModel)
            }
            .presentationDetents([.medium])
        }
        .overlay {
            if viewModel.isLoading, viewModel.conversations.isEmpty {
                ProgressView(L10n.ConversationsList.loading)
            }
        }
        .alert(item: $viewModel.alert) { alert in
            if alert.isRetryable {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text(L10n.Common.retry)) {
                        Task { await viewModel.loadConversations() }
                    },
                    secondaryButton: .cancel(Text(L10n.Common.cancel))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(L10n.Common.ok))
                )
            }
        }
    }
}

struct ConversationsListToolbarActionsView: View {
    let onSettingsTapped: () -> Void

    var body: some View {
        Button(action: handleSettingsTap) {
            Image(systemName: "gearshape")
                .font(.body.weight(.medium))
        }
        .foregroundStyle(.tertiary)
        .accessibilityLabel(L10n.Settings.navigationTitle)
        .accessibilityIdentifier("openSettingsButton")
    }

    @MainActor
    func handleSettingsTap() {
        onSettingsTapped()
    }
}

private struct RenameConversationSheet: View {
    @ObservedObject var viewModel: ConversationsListViewModel

    var body: some View {
        Form {
            Section {
                TextField(L10n.ConversationsList.renamePlaceholder, text: $viewModel.renameDraftTitle)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit {
                        guard viewModel.canSubmitConversationRename else { return }
                        Task {
                            await viewModel.commitConversationRename()
                        }
                    }
            }
        }
        .navigationTitle(L10n.ConversationsList.renameTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.Common.cancel) {
                    viewModel.cancelConversationRename()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.ConversationsList.renameSaveAction) {
                    Task {
                        await viewModel.commitConversationRename()
                    }
                }
                .disabled(!viewModel.canSubmitConversationRename)
            }
        }
    }
}

private struct NewConversationRowView: View {
    let accentColor: PromptAccentColor

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accentColor.color)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.ConversationsList.newConversationLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accentColor.color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(accentColor.color.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

private struct ConversationRowView: View {
    let conversation: Conversation
    let isGenerating: Bool
    let accentColor: PromptAccentColor

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .foregroundStyle(accentColor.color)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGenerating {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)

                    Text(L10n.ConversationsList.generatingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var displayTitle: String {
        guard let title = conversation.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return L10n.ConversationsList.defaultConversationTitle
        }
        return title
    }
}