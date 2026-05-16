import SwiftUI

struct CameraView: View {
    @StateObject private var camera = CameraManager.shared
    @State private var showToast = false
    @State private var toastText = ""
    @State private var toastIsError = false
    @State private var isHoveringPhoto = false
    @State private var isHoveringRecord = false
    @State private var pulseOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Camera preview
                ZStack {
                    Color.black.ignoresSafeArea()

                    if shouldShowPreview {
                        CameraPreviewView(session: camera.session)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))

                        // Recording indicator
                        if camera.status == .recording {
                            VStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 10, height: 10)
                                        .shadow(color: .red.opacity(0.6), radius: 4)
                                        .overlay(
                                            Circle()
                                                .fill(.red.opacity(pulseOpacity))
                                                .frame(width: 10, height: 10)
                                                .scaleEffect(1 + pulseOpacity * 2)
                                        )
                                    Text(formatRecordingDuration(camera.recordingDuration))
                                        .font(.caption.bold().monospaced())
                                        .foregroundStyle(.white)
                                    if camera.isAutoSegmenting {
                                        Text(Strings.recordingSegment)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                                    }
                                    Spacer()
                                    Text("REC")
                                        .font(.caption2.bold().monospaced())
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                Spacer()
                            }
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                    pulseOpacity = 0.6
                                }
                            }
                        }
                    } else {
                        placeholderView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Controls bar
                VStack(spacing: 0) {
                    Divider()

                    // Camera picker
                    if camera.availableCameras.count > 1 {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.on.rectangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker(Strings.selectCamera, selection: Binding(
                                get: { SettingsStore.shared.selectedCameraID.isEmpty ? camera.availableCameras.first?.uniqueID ?? "" : SettingsStore.shared.selectedCameraID },
                                set: { newID in
                                    if let device = camera.availableCameras.first(where: { $0.uniqueID == newID }) {
                                        camera.switchCamera(to: device)
                                    }
                                }
                            )) {
                                ForEach(camera.availableCameras, id: \.uniqueID) { device in
                                    Text(device.localizedName).tag(device.uniqueID)
                                }
                            }
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    // Status pill badge
                    HStack(spacing: 8) {
                        statusPill
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)

                    Divider()

                    // Buttons
                    HStack(spacing: 20) {
                        Button { camera.capturePhoto() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.body)
                                Text(Strings.takePhoto)
                                    .font(.body.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!camera.status.isOperational || camera.status == .recording)
                        .scaleEffect(isHoveringPhoto && camera.status == .running ? 1.02 : 1.0)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2)) { isHoveringPhoto = hovering }
                        }

                        if camera.status == .recording {
                            Button { camera.toggleRecording() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "stop.fill")
                                        .font(.body)
                                    Text(Strings.stopRecording)
                                        .font(.body.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.large)
                        } else {
                            Button { camera.toggleRecording() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "record.circle")
                                        .font(.body)
                                    Text(Strings.startRecording)
                                        .font(.body.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(!camera.status.isOperational)
                            .scaleEffect(isHoveringRecord && camera.status == .running ? 1.02 : 1.0)
                            .onHover { hovering in
                                withAnimation(.spring(response: 0.2)) { isHoveringRecord = hovering }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
            }

            // Toast
            if showToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showToast)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: camera.status)
        .onChange(of: camera.status) { _, newStatus in
            handleStatusChange(newStatus)
        }
        .onAppear {
            CaptureController.shared.cameraManager = camera
        }
    }

    // MARK: - Status Pill

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(camera.status.color)
                .frame(width: 7, height: 7)
                .shadow(color: camera.status.color.opacity(0.5), radius: 3)
            Text(statusTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(camera.status.color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(camera.status.color.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 10) {
            Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(toastIsError ? .red : .green)
            Text(toastText)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.top, 16)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showToast = false }
            }
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                Image(systemName: camera.status.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(camera.status.color)
            }

            Text(statusTitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            if camera.status == .permissionDenied {
                VStack(spacing: 12) {
                    Button(Strings.requestCameraAccess) {
                        camera.requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(Strings.openSystemSettings) {
                        camera.openSystemSettingsPrivacyCamera()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    // MARK: - Helpers

    private var shouldShowPreview: Bool {
        camera.status.isOperational
    }

    private var statusTitle: String {
        switch camera.status {
        case .checking: return Strings.checkingCamera
        case .noCamera: return Strings.noCameraDetected
        case .permissionDenied: return Strings.cameraAccessDenied
        case .sessionFailed(let msg): return "\(Strings.sessionFailed): \(msg)"
        case .running: return Strings.cameraRunning
        case .photoSaved(let name): return "\(Strings.saved): \(name)"
        case .recording: return Strings.stopRecording
        case .recordingSaved(let name): return "\(Strings.saved): \(name)"
        case .error(let msg): return msg
        case .stopped: return Strings.cameraStopped
        case .reconnecting: return Strings.reconnecting
        }
    }

    private func formatRecordingDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func handleStatusChange(_ newStatus: CameraStatus) {
        switch newStatus {
        case .photoSaved:
            toastText = Strings.photoSavedToast
            toastIsError = false
            withAnimation { showToast = true }
        case .recordingSaved:
            toastText = Strings.videoSavedToast
            toastIsError = false
            withAnimation { showToast = true }
        case .error(let msg):
            toastText = msg
            toastIsError = true
            withAnimation { showToast = true }
        default:
            break
        }
    }
}
