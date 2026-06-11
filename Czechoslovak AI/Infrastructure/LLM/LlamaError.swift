import Foundation

/// Typed errors thrown by `LlamaLLMEngine`.
public enum LlamaError: Error, LocalizedError {
    /// The GGUF model file was not found at the given path.
    case modelNotFound(path: String)
    /// llama.cpp failed to load or parse the model file.
    case modelLoadFailed
    /// The selected model architecture is not supported by this app.
    case unsupportedModelArchitecture(description: String)
    /// An inference context could not be created (e.g. insufficient memory).
    case contextCreationFailed
    /// The prompt could not be tokenised.
    case tokenizationFailed
    /// An error occurred during token-by-token inference.
    case inferenceFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return L10n.Llama.modelNotFound(path: path)
        case .modelLoadFailed:
            return L10n.Llama.modelLoadFailed
        case .unsupportedModelArchitecture(let description):
            return L10n.Llama.unsupportedModelArchitecture(description: description)
        case .contextCreationFailed:
            return L10n.Llama.contextCreationFailed
        case .tokenizationFailed:
            return L10n.Llama.tokenizationFailed
        case .inferenceFailed(let err):
            return L10n.Llama.inferenceFailed(err.localizedDescription)
        }
    }
}
