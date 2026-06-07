import SwiftUI

struct ConversationsListView: View {
    @ObservedObject var viewModel: ConversationsListViewModel
    let onSettingsTapped: () -> Void

    var body: some View {
        List {
            if viewModel.conversations.isEmpty, !viewModel.isLoading {
                ContentUnavailableView(
                    L10n.ConversationsList.emptyStateTitle,
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text(L10n.ConversationsList.emptyStateDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.conversations) { conversation in
                    Button {
                        viewModel.selectConversation(id: conversation.id)
                    } label: {
                        ConversationRowView(
                            conversation: conversation,
                            isGenerating: viewModel.isGenerating(conversationID: conversation.id)
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
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .accessibilityIdentifier("conversationsList")
        .navigationTitle(L10n.ConversationsList.navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onSettingsTapped()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(L10n.Settings.navigationTitle)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.createConversation(title: nil)
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(L10n.ConversationsList.newConversationLabel)
                .accessibilityIdentifier("createConversationButton")
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

private struct ConversationRowView: View {
    let conversation: Conversation
    let isGenerating: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .foregroundStyle(Color(.systemOrange))
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