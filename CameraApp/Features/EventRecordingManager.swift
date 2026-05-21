import Foundation

final class EventRecordingManager {
    static let shared = EventRecordingManager()

    private var isRecording = false

    private init() {}

    func handleMotionDetected() {
        guard SettingsStore.shared.eventRecordingEnabled else { return }
        guard !isRecording else { return }
        guard !CameraManager.shared.isVideoRecording else { return }

        isRecording = true
        let duration = SettingsStore.shared.eventClipDurationSeconds

        ActivityLogManager.shared.info(.motion, "Event recording started (\(duration)s)")

        CameraManager.shared.startEventClip(duration: TimeInterval(duration)) { [weak self] result in
            self?.isRecording = false
            switch result {
            case .success(let url):
                let fileName = url.lastPathComponent
                MediaIndexStore.shared.setSource(.event, for: fileName)
                ActivityLogManager.shared.success(.motion, "Event clip saved: \(fileName)")

                if SettingsStore.shared.autoUploadEventClips {
                    UploadQueueManager.shared.enqueue(fileName: fileName)
                }
            case .failure(let error):
                ActivityLogManager.shared.error(.motion, "Event recording failed", detail: error.localizedDescription)
            }
        }
    }
}
