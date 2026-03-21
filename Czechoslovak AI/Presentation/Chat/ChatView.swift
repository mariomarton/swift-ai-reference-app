import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    let onSearchTapped: () -> Void
    let onSettingsTapped: () -> Void

    init(
        viewModel: ChatViewModel,
        onSearchTapped: @escaping () -> Void,
        onSettingsTapped: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSearchTapped = onSearchTapped
        self.onSettingsTapped = onSettingsTapped
    }

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if viewModel.messages.isEmpty, !viewModel.isLoading, !viewModel.isSending {
                    ContentUnavailableView(
                        L10n.Chat.emptyStateTitle,
                        systemImage: "ellipsis.bubble",
                        description: Text(L10n.Chat.emptyStateDescription)
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isSending {
                                if let streaming = viewModel.streamingText {
                                    MessageBubbleView(message: Message(role: .assistant, text: streaming.isEmpty ? "..." : streaming))
                                        .opacity(0.75)
                                        .id("streaming")
                                } else {
                                    ThinkingIndicatorView(title: L10n.Chat.sendingIndicator)
                                        .id("streaming")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissActiveSelectionAndKeyboard()
                    }
                    .background(Color(.systemBackground))
                    .accessibilityIdentifier("messagesList")
                }
            }
            .navigationTitle(L10n.Chat.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ChatTopBarActionsView(
                        onSearchTapped: onSearchTapped,
                        onSettingsTapped: onSettingsTapped
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if viewModel.generationConflictPrompt != nil {
                        GenerationConflictBannerView(
                            message: L10n.Chat.generationConflictMessage,
                            waitActionTitle: L10n.Chat.generationConflictWaitAction,
                            stopAndSendActionTitle: L10n.Chat.generationConflictStopAndSendAction,
                            onWait: {
                                viewModel.dismissGenerationConflictPrompt()
                            },
                            onStopAndSend: {
                                viewModel.stopCurrentAndSendHere()
                            }
                        )
                    }

                    ComposerView(text: $viewModel.draftText, isSending: viewModel.isSending) {
                        if viewModel.isSending {
                            viewModel.stopGeneration()
                        } else {
                            Task {
                                await viewModel.sendMessage()
                            }
                        }
                    }
                }
            }
            .task {
                if viewModel.messages.isEmpty {
                    await viewModel.loadMessages()
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastID = viewModel.messages.last?.id else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.streamingText) { _, newValue in
                guard newValue != nil else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .overlay {
                if viewModel.isLoading, viewModel.messages.isEmpty {
                    ProgressView(L10n.Chat.loading)
                }
            }
            .alert(item: $viewModel.alert) { alert in
                if alert.isRetryable {
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text(L10n.Common.retry)) {
                            Task { await viewModel.loadMessages() }
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

    private func dismissActiveSelectionAndKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private struct ChatTopBarActionsView: View {
    let onSearchTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onSearchTapped()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel(L10n.Chat.searchConversationsLabel)
            .accessibilityIdentifier("searchConversationsButton")

            Button {
                onSettingsTapped()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel(L10n.Settings.navigationTitle)
            .accessibilityIdentifier("openSettingsButton")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct GenerationConflictBannerView: View {
    let message: String
    let waitActionTitle: String
    let stopAndSendActionTitle: String
    let onWait: () -> Void
    let onStopAndSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(waitActionTitle, action: onWait)
                    .buttonStyle(.bordered)

                Button(stopAndSendActionTitle, action: onStopAndSend)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 16)
    }
}

private struct ThinkingIndicatorView: View {
    let title: String
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color(.systemOrange))
                        .frame(width: 6, height: 6)
                        .scaleEffect(isAnimating ? 1 : 0.55)
                        .opacity(isAnimating ? 1 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.7)
                                .repeatForever()
                                .delay(Double(index) * 0.14),
                            value: isAnimating
                        )
                }
            }

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 4)
        .onAppear {
            isAnimating = true
        }
    }
}