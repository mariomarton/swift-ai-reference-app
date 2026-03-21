import Foundation

public enum DomainError: Error, LocalizedError {
    case repositoryError(Error)
    case engineError(Error)
    case invalidModel
    case unknown

    public var errorDescription: String? {
        switch self {
        case .repositoryError(let err):
            return "\(L10n.Errors.repositoryError): \(err.localizedDescription)"
        case .engineError(let err):
            return "\(L10n.Errors.engineError): \(err.localizedDescription)"
        case .invalidModel:
            return L10n.Errors.invalidModel
        case .unknown:
            return L10n.Errors.unknown
        }
    }
}
