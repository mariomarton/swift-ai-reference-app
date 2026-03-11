import Foundation

public enum DomainError: Error, LocalizedError {
    case repositoryError(Error)
    case engineError(Error)
    case invalidModel
    case unknown

    public var errorDescription: String? {
        switch self {
        case .repositoryError(let err):
            return "Repository error: \(err.localizedDescription)"
        case .engineError(let err):
            return "LLM engine error: \(err.localizedDescription)"
        case .invalidModel:
            return "Invalid or unsupported model"
        case .unknown:
            return "An unknown domain error occurred"
        }
    }
}
