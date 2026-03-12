# Domain layer notes

This folder contains pure domain types and use-case contracts. Keep the domain layer free of UI, Foundation-only or other platform-specific APIs where possible. Files added by the assistant:

- `Errors/DomainError.swift` - typed domain error adapter used by repositories and engines.
- `Models/Conversation.swift` - aggregates messages, metadata and selected model.
- `UseCases/SendMessageUseCase.swift` - protocol + default implementation that composes `ChatRepository` and `LLMEngine`.

Dependency injection expectations
- LLMEngine and ChatRepository are injected into use case implementations (for example, `DefaultSendMessageUseCase`).
- Implement concrete `ChatRepository` (in Infrastructure) that persists messages. Start with an in-memory or file-backed Codable store; later you can swap to CoreData or SQLite without changing use-cases.
- Implement a concrete `LLMEngine` (in Infrastructure) that either runs a local model or delegates to a service. Ensure it conforms to `LLMEngine` and throws errors that can be wrapped in `DomainError.engineError`.

# Added use-cases

- `UseCases/LoadRecentMessagesUseCase.swift` - protocol + `DefaultLoadRecentMessagesUseCase` implementation that returns optionally limited, sorted recent messages and wraps repository errors in `DomainError`.
- `UseCases/ClearAllMessagesUseCase.swift` - protocol + `DefaultClearAllMessagesUseCase` to clear all persisted messages via `ChatRepository`.

Testing
- Use the domain-level mock implementations (like those added to `Czechoslovak AITests/Domain/SendMessageUseCaseTests.swift`) to test use-case logic.
- Unit tests were added under `Czechoslovak AITests/Domain`:
  - `SendMessageUseCaseTests.swift` - mocks for `ChatRepository` and `LLMEngine` and tests for `DefaultSendMessageUseCase` covering success and engine error wrapping.
  - `LoadAndClearUseCasesTests.swift` - tests for `DefaultLoadRecentMessagesUseCase` and `DefaultClearAllMessagesUseCase` including sorting, limiting, clearing, and error wrapping.
  - `ConversationAndErrorTests.swift` - tests for `Conversation` behavior and `DomainError` description content.

To run tests locally using Xcode:
1. Open `Czechoslovak AI.xcworkspace` in Xcode.
2. Select the `Czechoslovak AI` scheme and run Product → Test (or press Cmd+U).

From the command line (requires Xcode/Simulator):

```bash
# Run unit tests for the app scheme (adjust simulator name if needed)
xcodebuild test -workspace "Czechoslovak AI.xcworkspace" -scheme "Czechoslovak AI" -destination 'platform=iOS Simulator,name=iPhone 14'
```

Note: This environment may not have Xcode command line tools configured; if `xcodebuild` reports an error, open the workspace in Xcode and run tests there.

# Dependency injection guidance

- Keep injecting `ChatRepository` and `LLMEngine` into use-cases rather than creating them inside use-cases. This allows easy substitution with mocks for unit tests and with real implementations in production.

# Next suggestions

- Add a simple file-backed `ChatRepository` in `Infrastructure/` for early persistence during UI development.
- Add integration tests once you have a concrete `LLMEngine` implementation (local or remote).

# File-backed repository (Infrastructure)

A sample implementation `FileBackedChatRepository` was added under `Infrastructure/Repositories`.

Key points:
- Uses `Codable` + `JSONEncoder`/`JSONDecoder` and `FileManager` to persist messages to a JSON file.
- Is implemented as a Swift `actor` to provide concurrency safety and an in-memory cache for fast reads.
- Uses atomic writes (temporary file + replace/move) to avoid corrupting the storage file.
- Injects `FileManager` and accepts a `storageURL` to make testing easier (tests use a temporary directory).

Tests
- Integration tests for `FileBackedChatRepository` live under `Czechoslovak AITests/Infrastructure/FileBackedChatRepositoryTests.swift`. They exercise persistence, clearing, instance-level persistence, and concurrent writes.

Swap out for production storage
- Keep the `ChatRepository` protocol as the boundary — you can replace `FileBackedChatRepository` with a production implementation (Core Data / SQLite / Realm) without changing use-cases or higher layers.
