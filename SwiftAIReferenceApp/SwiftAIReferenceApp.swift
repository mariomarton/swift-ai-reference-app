import SwiftUI

@main
struct SwiftAIReferenceApp: App {
    private let dependenciesResult: Result<AppDependencies, Error>

    init() {
        dependenciesResult = Result {
            try AppDependencies()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch dependenciesResult {
            case .success(let dependencies):
                ContentView(dependencies: dependencies)
            case .failure(let error):
                AppLaunchErrorView(error: error)
            }
        }
    }
}

private struct AppLaunchErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView(
            L10n.App.failedToStartTitle,
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
        .padding()
    }
}
