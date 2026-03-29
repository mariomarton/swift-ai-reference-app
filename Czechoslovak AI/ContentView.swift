//
//  ContentView.swift
//  Czechoslovak AI
//

//

import SwiftUI

struct ContentView: View {
    private let dependencies: AppDependencies
    @StateObject private var viewModel: ConversationsListViewModel
    @State private var path: [AppRoute] = []

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: dependencies.makeConversationsListViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            ConversationsListView(viewModel: viewModel)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .chat(let conversationID):
                        ChatView(viewModel: dependencies.makeChatViewModel(conversationID: conversationID))
                    }
                }
        }
        .onChange(of: viewModel.selectedConversationID) { _, newValue in
            guard let conversationID = newValue else { return }

            let route = AppRoute.chat(conversationID: conversationID)
            if path.last != route {
                path.append(route)
            }

            viewModel.selectedConversationID = nil
        }
    }
}

#Preview {
    if let dependencies = try? AppDependencies() {
        ContentView(dependencies: dependencies)
    } else {
        Text("Preview unavailable")
    }
}
