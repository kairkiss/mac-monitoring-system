import Foundation

struct APICameraHandler {
    static func register(router: WebRouter) {
        // Camera snapshot (JPEG)
        router.addRoute(method: "GET", path: "/api/camera/preview") { _ in
            let camera = CameraManager.shared
            guard camera.isSessionRunning else {
                return HTTPResponse.error("Camera not running", status: 503)
            }

            // Return a placeholder status — actual snapshot requires async capture
            return HTTPResponse.json([
                "status": "Camera is running",
                "deviceName": camera.activeCameraName ?? "Unknown"
            ])
        }

        // Capture photo
        router.addRoute(method: "POST", path: "/api/camera/capture") { _ in
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
        router.addRoute(method: "POST", path: "/api/camera/switch") { request in
            guard let body = request.body,
                  let json = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let deviceID = json["deviceID"] else {
                return HTTPResponse.error("Missing deviceID")
            }

            let camera = CameraManager.shared
            camera.switchCamera(to: deviceID)
            return HTTPResponse.ok()
        }
    }
}
