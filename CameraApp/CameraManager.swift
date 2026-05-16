import AVFoundation
import AppKit
import SwiftUI

enum CameraStatus: Equatable {
    case checking
    case noCamera
    case permissionDenied
    case sessionFailed(String)
    case running
    case photoSaved(String)
    case recording
    case recordingSaved(String)
    case error(String)
    case stopped
    case reconnecting

    var icon: String {
        switch self {
        case .checking: return "hourglass.circle"
        case .noCamera: return "video.slash"
        case .permissionDenied: return "lock.circle"
        case .sessionFailed: return "exclamationmark.triangle"
        case .running: return "video.circle.fill"
        case .photoSaved: return "photo.circle.fill"
        case .recording: return "record.circle"
        case .recordingSaved: return "film.circle.fill"
        case .error: return "exclamationmark.circle"
        case .stopped: return "video.slash"
        case .reconnecting: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .checking: return .orange
        case .noCamera, .permissionDenied: return .red
        case .sessionFailed, .error: return .red
        case .running: return .green
        case .photoSaved, .recordingSaved: return .blue
        case .recording: return .red
        case .stopped: return .gray
        case .reconnecting: return .orange
        }
    }
}

final class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()

    @Published var status: CameraStatus = .checking
    @Published var lastSavedPhotoPath: String?
    @Published var lastSavedVideoPath: String?
    @Published var availableCameras: [AVCaptureDevice] = []

    nonisolated let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private nonisolated let movieOutput = AVCaptureMovieFileOutput()

    private nonisolated let videoOutput = AVCaptureVideoDataOutput()
    private var latestSampleBuffer: CMSampleBuffer?
    private let sampleBufferQueue = DispatchQueue(label: "camera.sampleBuffer")

    private var isSessionRunning = false
    private var isInBackground = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: DispatchWorkItem?

    var selectedDevice: AVCaptureDevice? {
        let savedID = SettingsStore.shared.selectedCameraID
        if !savedID.isEmpty, let device = AVCaptureDevice(uniqueID: savedID) {
            return device
        }
        return availableCameras.first ?? AVCaptureDevice.default(for: .video)
    }

    var isCameraBusyByOtherApp: Bool {
        guard let device = selectedDevice else { return true }
        return device.isConnected == false || device.isInUseByAnotherApplication
    }

    override init() {
        super.init()
        refreshAvailableCameras()
        checkInitialStatus()
        setupNotifications()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(cameraWasDisconnected),
            name: .AVCaptureDeviceWasDisconnected, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(cameraWasConnected),
            name: .AVCaptureDeviceWasConnected, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        isInBackground = false
        refreshAvailableCameras()
        if !isSessionRunning {
            startSession()
        }
    }

    @objc private func appDidResignActive() {
        isInBackground = true
        if !AutomationScheduler.shared.isAutomationEnabled {
            stopSession()
        }
    }

    @objc private func cameraWasDisconnected() {
        refreshAvailableCameras()
        guard isSessionRunning else { return }
        DispatchQueue.main.async { [weak self] in
            self?.status = .reconnecting
        }
        reconnectAttempts = 0
        scheduleReconnect()
    }

    @objc private func cameraWasConnected() {
        refreshAvailableCameras()
        if status == .reconnecting || status == .noCamera {
            reconnectAttempts = 0
            attemptReconnect()
        }
    }

    @objc private func systemWillSleep() {
        guard isSessionRunning else { return }
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }

    @objc private func systemDidWake() {
        refreshAvailableCameras()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if !self.isSessionRunning {
                self.status = .reconnecting
                self.reconnectAttempts = 0
                self.attemptReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.cancel()
        let delay = min(pow(2.0, Double(reconnectAttempts)) * 0.5, 16.0)
        reconnectAttempts += 1
        guard reconnectAttempts <= maxReconnectAttempts else {
            DispatchQueue.main.async { [weak self] in
                self?.status = .error("Camera disconnected")
            }
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.attemptReconnect()
        }
        reconnectTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func attemptReconnect() {
        guard selectedDevice != nil else {
            scheduleReconnect()
            return
        }
        startSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if self.isSessionRunning {
                self.reconnectAttempts = 0
            } else {
                self.scheduleReconnect()
            }
        }
    }

    // MARK: - Camera Selection

    func refreshAvailableCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        DispatchQueue.main.async { [weak self] in
            self?.availableCameras = discovery.devices
        }
    }

    func switchCamera(to device: AVCaptureDevice) {
        SettingsStore.shared.selectedCameraID = device.uniqueID
        guard isSessionRunning else { return }
        stopSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startSession()
        }
    }

    // MARK: - Authorization

    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.startSession()
                } else {
                    self.status = .permissionDenied
                }
            }
        }
    }

    func openSystemSettingsPrivacyCamera() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Photo Capture

    /// Capture photo regardless of status. Starts session if needed.
    func capturePhoto() {
        // If session is not running, start it first then capture
        if !isSessionRunning {
            startSession()
            // Wait for session to be ready, then capture
            var attempts = 0
            var check: (() -> Void)!
            check = { [weak self] in
                guard let self else { return }
                attempts += 1
                if self.isSessionRunning {
                    // Session ready, wait a bit for first frame
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.doCapturePhoto()
                    }
                } else if attempts < 30 { // 9 seconds max
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check?() }
                } else {
                    self.status = .error("Camera failed to start")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check() }
            return
        }

        doCapturePhoto()
    }

    private func doCapturePhoto() {
        guard let sampleBuffer = latestSampleBuffer,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            // No frame yet, wait a bit and retry once
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.doCapturePhotoDirect()
            }
            return
        }

        savePhoto(from: imageBuffer)
    }

    private func doCapturePhotoDirect() {
        guard let sampleBuffer = latestSampleBuffer,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            status = .error("No video frame available")
            return
        }
        savePhoto(from: imageBuffer)
    }

    private func savePhoto(from imageBuffer: CVImageBuffer) {
        var ciImage = CIImage(cvImageBuffer: imageBuffer)
        if SettingsStore.shared.enableWatermark {
            ciImage = applyWatermark(to: ciImage)
        }
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            status = .error("Failed to create image")
            return
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            status = .error("Failed to encode JPEG")
            return
        }

        let lib = MediaLibraryManager.shared
        lib.ensureDirectoriesExist()
        let fileName = "Photo_\(timestampString()).jpg"
        let url = lib.photosDirectory.appendingPathComponent(fileName)
        do {
            try jpegData.write(to: url)
            lib.registerPhoto(fileName: fileName, fileSize: Int64(jpegData.count))
            lastSavedPhotoPath = url.path
            status = .photoSaved(fileName)
            // Auto-reset to running after 2.5s so button re-enables
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                if case .photoSaved = self.status {
                    self.status = .running
                }
            }
        } catch {
            status = .error("Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Video Recording

    func toggleRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Session Management

    func ensureSessionRunning(then completion: @escaping () -> Void) {
        if isSessionRunning && status == .running {
            completion()
            return
        }
        startSession()
        var attempts = 0
        var check: (() -> Void)!
        check = { [weak self] in
            guard let self else { return }
            attempts += 1
            if self.isSessionRunning {
                completion()
            } else if attempts < 30 { // 9 seconds max
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check?() }
            } else {
                // Timeout - try to start fresh
                self.status = .checking
                self.startSession()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check() }
    }

    func stopSession() {
        guard isSessionRunning else { return }
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
                self?.status = .stopped
            }
        }
    }

    // MARK: - Private

    private func checkInitialStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            status = .permissionDenied
        case .denied, .restricted:
            status = .permissionDenied
        @unknown default:
            status = .permissionDenied
        }
    }

    private func startSession() {
        guard !isSessionRunning else { return }
        sessionQueue.async { [weak self] in
            self?.configureAndStartSession()
        }
    }

    private nonisolated func configureAndStartSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }

        guard let camera = selectedDevice else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.status = .noCamera
            }
            return
        }

        if camera.isInUseByAnotherApplication {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.status = .error("Camera in use by another app")
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.status = .sessionFailed(error.localizedDescription)
            }
            return
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSessionRunning = true
            if self.session.inputs.isEmpty {
                self.status = .sessionFailed("No camera input available")
            } else {
                self.status = .running
            }
        }
    }

    private func startRecording() {
        guard movieOutput.connection(with: .video) != nil else {
            status = .error("No video connection available")
            return
        }
        let lib = MediaLibraryManager.shared
        lib.ensureDirectoriesExist()
        let fileName = "Video_\(timestampString()).mov"
        let url = lib.videosDirectory.appendingPathComponent(fileName)
        movieOutput.startRecording(to: url, recordingDelegate: self)
        status = .recording
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    private func applyWatermark(to image: CIImage) -> CIImage {
        let timestamp = Date().formatted(date: .abbreviated, time: .shortened)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (timestamp as NSString).size(withAttributes: textAttributes)
        let padding: CGFloat = 12
        let bgSize = NSSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)

        let bgImage = NSImage(size: bgSize)
        bgImage.lockFocus()
        NSColor.black.withAlphaComponent(0.5).setFill()
        let bgRect = NSRect(origin: .zero, size: bgSize)
        let path = NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6)
        path.fill()
        let textPoint = NSPoint(x: padding, y: padding)
        (timestamp as NSString).draw(at: textPoint, withAttributes: textAttributes)
        bgImage.unlockFocus()

        guard let bgCGImage = bgImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        let watermarkCI = CIImage(cgImage: bgCGImage)
        let margin: CGFloat = 20
        let xPos = image.extent.width - bgSize.width - margin
        let yPos = margin
        let positioned = watermarkCI.transformed(by: CGAffineTransform(translationX: xPos, y: yPos))

        guard let filter = CIFilter(name: "CISourceOverCompositing") else { return image }
        filter.setValue(positioned, forKey: kCIInputImageKey)
        filter.setValue(image, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? image
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        latestSampleBuffer = sampleBuffer
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let error {
                self.status = .error("Recording failed: \(error.localizedDescription)")
                return
            }
            let lib = MediaLibraryManager.shared
            let fileName = outputFileURL.lastPathComponent
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            lib.registerVideo(fileName: fileName, fileSize: size)
            self.lastSavedVideoPath = outputFileURL.path
            self.status = .recordingSaved(fileName)
        }
    }
}
