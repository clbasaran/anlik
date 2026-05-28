import Foundation
import ActivityKit

/// Manages Live Activities for photo upload progress on Dynamic Island
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<PhotoUploadAttributes>?

    private init() {}

    /// Start a Live Activity when photo upload begins
    func startUploadActivity(recipientCount: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PhotoUploadAttributes(
            recipientCount: recipientCount,
            photoTimestamp: Date()
        )

        let initialState = PhotoUploadAttributes.ContentState(
            progress: 0.0,
            status: .uploading
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            AppLogger.service.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Update progress during upload
    func updateProgress(_ progress: Double) {
        guard let activity = currentActivity else { return }

        let state = PhotoUploadAttributes.ContentState(
            progress: min(1.0, progress),
            status: progress >= 0.9 ? .processing : .uploading
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Mark upload as completed and end the activity
    func completeUpload() {
        guard let activity = currentActivity else { return }

        let finalState = PhotoUploadAttributes.ContentState(
            progress: 1.0,
            status: .completed
        )

        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 3)  // Dismiss after 3 seconds
            )
            currentActivity = nil
        }
    }

    /// Mark upload as failed and end
    func failUpload() {
        guard let activity = currentActivity else { return }

        let failedState = PhotoUploadAttributes.ContentState(
            progress: 0.0,
            status: .failed
        )

        Task {
            await activity.end(
                .init(state: failedState, staleDate: nil),
                dismissalPolicy: .after(.now + 5)
            )
            currentActivity = nil
        }
    }
}
