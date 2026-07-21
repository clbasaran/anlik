import Foundation
import ActivityKit
import Observation

/// Observable mirror of the upload progress so in-app surfaces (the top
/// breathing line) can render a determinate fill from the same milestones
/// that drive the Dynamic Island.
@MainActor
@Observable
final class UploadProgressState {
    static let shared = UploadProgressState()
    /// nil when no upload is in flight; 0...1 while uploading.
    var progress: Double?
    private init() {}
}

/// Manages Live Activities for photo upload progress on Dynamic Island
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<PhotoUploadAttributes>?

    private init() {}

    /// Start a Live Activity when photo upload begins
    func startUploadActivity(recipientCount: Int) {
        UploadProgressState.shared.progress = 0.05
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
        UploadProgressState.shared.progress = min(1.0, progress)
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
        UploadProgressState.shared.progress = nil
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
        UploadProgressState.shared.progress = nil
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
