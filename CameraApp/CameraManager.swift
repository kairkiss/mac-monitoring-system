import AVFoundation
import AppKit
import SwiftUI

enum CameraCaptureError: LocalizedError {
    case noVideoFrame
    case imageCreationFailed
    case jpegEncodingFailed
    case diskSpaceInsufficient
    case saveFailed
    case cameraNotReady

    var errorDescription: String? {
        switch self {
        case .noVideoFrame: return Strings.noVideoFrame
        case .imageCreationFailed: return Strings.imageCreationFailed
        case .jpegEncodingFailed: return Strings.jpegEncodingFailed
        case .diskSpaceInsufficient: return Strings.diskSpaceInsufficient
        case .saveFailed: return Strings.captureFailed
        case .cameraNotReady: return Strings.cameraStopped
        }
    }
}

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

    var isOperational: Bool {
        switch self {
        case .running, .photoSaved, .recording, .recordingSaved, .reconnecting: return true
        default: return false
        }
    }
}

final class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()

    @Published var status: CameraStatus = .checking
    @Published var lastSavedPhotoPath: String?
    @Published var lastSavedVideoPath: String?
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var isAutoSegmenting: Bool = false

    nonisolated let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private nonisolated let movieOutput = AVCaptureMovieFileOutput()

    private nonisolated let videoOutput = AVCaptureVideoDataOutput()
    private var latestSampleBuffer: CMSampleBuffer?
    private let sampleBufferQueue = DispatchQueue(label: "camera.sampleBuffer")

    private var isSessionRunning = false
    private var isInBackground = false
    private var isConfiguring = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: DispatchWorkItem?
    private var recordingTimer: Timer?
    private var recordingStartDate: Date?
    private var currentSegmentIndex: Int = 0

    var selectedDevice: AVCaptureDevice? {
        let savedID = SettingsStore.shared.selectedCameraID
        if !savedID.isEmpty, let device = AVCaptureDevice(uniqueID: savedID), device.isConnected {
            return device
        }
        // Fall back to any connected camera
        if let first = availableCameras.first(where: { $0.isConnected }) {
            return first
        }
        return AVCaptureDevice.default(for: .video)
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
        // Smart switch: if another camera is available, switch immediately
        if switchToAvailableCamera() {
            return
        }
        scheduleReconnect()
    }

    @objc private func cameraWasConnected() {
        refreshAvailableCameras()
        if status == .reconnecting || status == .noCamera {
            reconnectAttempts = 0
            attemptReconnect()
        }
    }

    /// Try to switch to another available camera. Returns true if switch was initiated.
    private func switchToAvailableCamera() -> Bool {
        guard !availableCameras.isEmpty else { return false }
        let currentID = SettingsStore.shared.selectedCameraID
        // Find a camera that's not the current one and is connected
        let alternative = availableCameras.first { $0.uniqueID != currentID && $0.isConnected }
        guard let newCamera = alternative else { return false }
        SettingsStore.shared.selectedCameraID = newCamera.uniqueID
        stopSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startSession()
        }
        return true
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
        // Try to switch to any available camera first
        if switchToAvailableCamera() { return }
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

    func capturePhoto(completion: ((Result<URL, CameraCaptureError>) -> Void)? = nil) {
        if !isSessionRunning {
            startSession()
            var attempts = 0
            var check: (() -> Void)!
            check = { [weak self] in
                guard let self else { return }
                attempts += 1
                if self.isSessionRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.doCapturePhoto(completion: completion)
                    }
                } else if attempts < 30 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check?() }
                } else {
                    self.status = .error(Strings.cameraStopped)
                    completion?(.failure(.cameraNotReady))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check() }
            return
        }
        doCapturePhoto(completion: completion)
    }

    private func doCapturePhoto(completion: ((Result<URL, CameraCaptureError>) -> Void)?) {
        guard let sampleBuffer = latestSampleBuffer,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.doCapturePhotoDirect(completion: completion)
            }
            return
        }
        savePhoto(from: imageBuffer, completion: completion)
    }

    private func doCapturePhotoDirect(completion: ((Result<URL, CameraCaptureError>) -> Void)?) {
        guard let sampleBuffer = latestSampleBuffer,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            status = .error(Strings.noVideoFrame)
            completion?(.failure(.noVideoFrame))
            return
        }
        savePhoto(from: imageBuffer, completion: completion)
    }

    private func savePhoto(from imageBuffer: CVImageBuffer, completion: ((Result<URL, CameraCaptureError>) -> Void)?) {
        guard MediaLibraryManager.shared.hasEnoughDiskSpace() else {
            status = .error(Strings.diskSpaceInsufficient)
            completion?(.failure(.diskSpaceInsufficient))
            return
        }

        var ciImage = CIImage(cvImageBuffer: imageBuffer)
        if SettingsStore.shared.enableWatermark {
            ciImage = applyWatermark(to: ciImage)
        }
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            status = .error(Strings.imageCreationFailed)
            completion?(.failure(.imageCreationFailed))
            return
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            status = .error(Strings.jpegEncodingFailed)
            completion?(.failure(.jpegEncodingFailed))
            return
        }

        let lib = MediaLibraryManager.shared
        lib.ensureDirectoriesExist()
        let fileName = "Photo_\(timestampString()).jpg"
        let url = lib.photosDirectory.appendingPathComponent(fileName)
        if lib.writeAtomically(jpegData, to: url) {
            lib.registerPhoto(fileName: fileName, fileSize: Int64(jpegData.count))
            MediaIndexStore.shared.setSource(.manual, for: fileName)
            lastSavedPhotoPath = url.path
            status = .photoSaved(fileName)
            completion?(.success(url))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                if case .photoSaved = self.status {
                    self.status = .running
                }
            }
        } else {
            status = .error(Strings.captureFailed)
            completion?(.failure(.saveFailed))
        }
    }

    // MARK: - Video Recording

    func toggleRecording() {
        if movieOutput.isRecording {
            stopRecordingTimer()
            movieOutput.stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Recording Timer

    private func startRecordingTimer() {
        recordingStartDate = Date()
        recordingDuration = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.recordingStartDate else { return }
            self.recordingDuration = Date().timeIntervalSince(startDate)
            self.checkAutoSegment()
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartDate = nil
        recordingDuration = 0
        currentSegmentIndex = 0
    }

    private func checkAutoSegment() {
        let segmentMinutes = SettingsStore.shared.segmentDurationMinutes
        guard segmentMinutes > 0 else { return }
        let segmentDuration = TimeInterval(segmentMinutes * 60)
        guard recordingDuration >= segmentDuration else { return }

        isAutoSegmenting = true
        currentSegmentIndex += 1
        movieOutput.stopRecording()
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
            } else if attempts < 30 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { check?() }
            } else {
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
        guard !isSessionRunning && !isConfiguring else { return }
        sessionQueue.async { [weak self] in
            self?.configureAndStartSession()
        }
    }

    private nonisolated func configureAndStartSession() {
        guard !isConfiguring else { return }
        isConfiguring = true
        defer { isConfiguring = false }

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

        // Audio input (if enabled and available)
        if SettingsStore.shared.enableAudioRecording {
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if session.canAddInput(audioInput) {
                        session.addInput(audioInput)
                    }
                } catch {
                    ActivityLogManager.shared.warning(.camera, Strings.audioNotAvailable, detail: error.localizedDescription)
                }
            }
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
            status = .error(Strings.noVideoFrame)
            return
        }
        guard MediaLibraryManager.shared.hasEnoughDiskSpace() else {
            status = .error(Strings.diskSpaceInsufficient)
            return
        }
        let lib = MediaLibraryManager.shared
        lib.ensureDirectoriesExist()
        let fileName = "Video_\(timestampString()).mov"
        let url = lib.videosDirectory.appendingPathComponent(fileName)
        movieOutput.startRecording(to: url, recordingDelegate: self)
        status = .recording
        startRecordingTimer()
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
        HealthMonitor.shared.recordFrameReceived()
        MotionDetector.shared.processFrame(sampleBuffer)
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
                self.stopRecordingTimer()
                return
            }
            let lib = MediaLibraryManager.shared
            let fileName = outputFileURL.lastPathComponent
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let asset = AVURLAsset(url: outputFileURL)
            let dur = CMTimeGetSeconds(asset.duration)
            let videoDuration: TimeInterval? = dur.isNaN ? nil : dur
            lib.registerVideo(fileName: fileName, fileSize: size, duration: videoDuration)
            self.lastSavedVideoPath = outputFileURL.path

            if self.isAutoSegmenting {
                self.isAutoSegmenting = false
                self.status = .recording
                self.startRecording()
            } else {
                self.stopRecordingTimer()
                self.status = .recordingSaved(fileName)
            }
        }
    }
}
