import Foundation

struct APICameraHandler {
    static func register(router: WebRouter) {
        // Camera snapshot JPEG (real image)
        router.addRoute(method: "GET", path: "/api/camera/snapshot.jpg") { _ in
            let camera = CameraManager.shared
            guard camera.isSessionRunning else {
                return HTTPResponse.error("Camera not running", status: 503)
            }
            guard let jpegData = camera.latestSnapshotJPEG() else {
                return HTTPResponse.error("No frame available", status: 503)
            }
            return HTTPResponse(
                status: 200,
                statusText: "OK",
                headers: [
                    "Content-Type": "image/jpeg",
                    "Content-Length": "\(jpegData.count)",
                    "Cache-Control": "no-cache"
                ],
                body: jpegData
            )
        }

        // Camera status (JSON)
        router.addRoute(method: "GET", path: "/api/camera/preview") { _ in
            let camera = CameraManager.shared
            guard camera.isSessionRunning else {
                return HTTPResponse.error("Camera not running", status: 503)
            }

            let deviceName = camera.activeCameraName.isEmpty ? "Unknown" : camera.activeCameraName
            return HTTPResponse.json([
                "status": "Camera is running",
                "deviceName": deviceName
            ])
        }

        // Capture photo
        router.addRoute(method: "POST", path: "/api/camera/capture", requiredRole: .operatorRole) { _ in
            let camera = CameraManager.shared
            let semaphore = DispatchSemaphore(value: 0)
            var captureResult: Result<URL, CameraCaptureError>?
            camera.ensureSessionRunning {
                camera.capturePhoto { r in
                    captureResult = r
                    semaphore.signal()
                }
            }
            semaphore.wait()
            switch captureResult {
            case .success(let url):
                let fileName = url.lastPathComponent
                MediaIndexStore.shared.setSource(.manual, for: fileName)
                return HTTPResponse.json([
                    "status": "captured",
                    "fileName": fileName,
                    "path": url.path
                ] as [String: Any])
            case .failure(let error):
                return HTTPResponse.error("Capture failed: \(error.localizedDescription)", status: 500)
            case .none:
                return HTTPResponse.error("Camera not available", status: 503)
            }
        }

        // Get camera devices
        router.addRoute(method: "GET", path: "/api/camera/devices") { _ in
            let camera = CameraManager.shared
            let devices = camera.availableCameras.map { cam in
                [
                    "id": cam.uniqueID,
                    "name": cam.localizedName,
                    "isSelected": cam.uniqueID == camera.currentDeviceID
                ] as [String: Any]
            }
            return HTTPResponse.json(["devices": devices])
        }

        // Switch camera
        router.addRoute(method: "POST", path: "/api/camera/switch", requiredRole: .operatorRole) { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let deviceID = json["deviceID"] else {
                return HTTPResponse.error("Missing deviceID")
            }

            let camera = CameraManager.shared
            camera.switchCamera(to: deviceID)
            return HTTPResponse.ok()
        }

        // Start recording
        router.addRoute(method: "POST", path: "/api/camera/record/start", requiredRole: .operatorRole) { _ in
            let camera = CameraManager.shared
            guard !camera.isVideoRecording else {
                return HTTPResponse.error("Already recording", status: 409)
            }
            let semaphore = DispatchSemaphore(value: 0)
            var startResult: Result<URL, Error>?
            camera.ensureSessionRunning {
                camera.startRecording { r in
                    startResult = r
                    semaphore.signal()
                }
            }
            semaphore.wait()
            switch startResult {
            case .success(let url):
                return HTTPResponse.json(["status": "recording", "fileName": url.lastPathComponent])
            case .failure(let error):
                return HTTPResponse.error("Recording failed: \(error.localizedDescription)", status: 500)
            case .none:
                return HTTPResponse.error("Camera not available", status: 503)
            }
        }

        // Stop recording
        router.addRoute(method: "POST", path: "/api/camera/record/stop", requiredRole: .operatorRole) { _ in
            let camera = CameraManager.shared
            guard camera.isVideoRecording else {
                return HTTPResponse.error("Not recording", status: 409)
            }
            let semaphore = DispatchSemaphore(value: 0)
            var stopResult: Result<URL, Error>?
            camera.stopRecording { r in
                stopResult = r
                semaphore.signal()
            }
            semaphore.wait()
            switch stopResult {
            case .success(let url):
                return HTTPResponse.json(["status": "saved", "fileName": url.lastPathComponent])
            case .failure(let error):
                return HTTPResponse.error("Stop failed: \(error.localizedDescription)", status: 500)
            case .none:
                return HTTPResponse.ok()
            }
        }

        // Recording status
        router.addRoute(method: "GET", path: "/api/camera/record/status") { _ in
            let camera = CameraManager.shared
            let deviceName = camera.activeCameraName.isEmpty ? "Unknown" : camera.activeCameraName
            return HTTPResponse.json([
                "isRecording": camera.isVideoRecording,
                "isSessionRunning": camera.isSessionRunning,
                "deviceName": deviceName
            ] as [String: Any])
        }
    }
}
