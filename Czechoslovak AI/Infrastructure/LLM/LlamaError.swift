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
            return "Model file not found at path: \(path)"
        case .modelLoadFailed:
            return "Failed to load model — the file may be corrupted or in an unsupported format."
        case .unsupportedModelArchitecture(let description):
            return "Unsupported model architecture: \(description). Use a decoder-only instruct/chat GGUF model."
        case .contextCreationFailed:
            return "Failed to create inference context — the device may not have enough memory."
        case .tokenizationFailed:
            return "Failed to tokenise the input prompt."
        case .inferenceFailed(let err):
            return "Inference failed: \(err.localizedDescription)"
        }
    }
}
