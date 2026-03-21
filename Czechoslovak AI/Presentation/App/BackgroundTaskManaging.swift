import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol BackgroundTaskManaging: AnyObject {
    @discardableResult
    func beginTask(for conversationID: UUID, expirationHandler: @escaping @Sendable () -> Void) -> Bool

    func endTask(for conversationID: UUID)
}

@MainActor
final class UIKitBackgroundTaskManager: BackgroundTaskManaging {
    #if canImport(UIKit)
    private var taskIDs: [UUID: UIBackgroundTaskIdentifier] = [:]
    #endif

    @discardableResult
    func beginTask(for conversationID: UUID, expirationHandler: @escaping @Sendable () -> Void) -> Bool {
        #if canImport(UIKit)
        if taskIDs[conversationID] != nil {
            return true
        }

        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "generation.\(conversationID.uuidString)") {
            expirationHandler()
        }

        guard taskID != .invalid else {
            return false
        }

        taskIDs[conversationID] = taskID
        return true
        #else
        return false
        #endif
    }

    func endTask(for conversationID: UUID) {
        #if canImport(UIKit)
        guard let taskID = taskIDs.removeValue(forKey: conversationID), taskID != .invalid else {
            return
        }

        UIApplication.shared.endBackgroundTask(taskID)
        #endif
    }
}