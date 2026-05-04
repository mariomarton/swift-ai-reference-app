import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                        Text(L10n.Chat.sendingIndicator)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
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
            .safeAreaInset(edge: .bottom) {
                ComposerView(text: $viewModel.draftText, isSending: viewModel.isSending) {
                    Task {
                        await viewModel.sendMessage()
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
                        primaryButton: .default(Text("Zopakovať")) {
                            Task { await viewModel.loadMessages() }
                        },
                        secondaryButton: .cancel(Text("Zrušiť"))
                    )
                } else {
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
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