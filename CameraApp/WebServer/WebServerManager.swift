import Foundation

final class WebServerManager: ObservableObject {
    static let shared = WebServerManager()

    @Published private(set) var isRunning = false

    private var server: HTTPServer?
    private let router = WebRouter()
    private let auditLogger = AuditLogManager.shared

    private init() {}

    func start() {
        guard !isRunning else { return }

        let settings = SettingsStore.shared
        guard settings.webServerEnabled else { return }

        let port = UInt16(settings.webServerPort)
        let bindAddr = settings.webServerBindAddress

        // Configure static file root
        if let webRoot = Bundle.main.resourceURL?.appendingPathComponent("Web") {
            router.setStaticFileRoot(webRoot)
        }

        // Register API routes
        registerRoutes()

        let server = HTTPServer(
            port: port,
            bindAddress: bindAddr,
            router: router,
            auditLogger: auditLogger
        )

        do {
            try server.start()
            self.server = server
            isRunning = true
        } catch {
            ActivityLogManager.shared.error(.webServer, "Failed to start web server", detail: error.localizedDescription)
            HealthMonitor.shared.recordAlert(type: .webServerError, message: "Failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        server?.stop()
        server = nil
        isRunning = false
    }

    func restart() {
        stop()
        start()
    }

    private func registerRoutes() {
        // Auth routes
        APIAuthHandler.register(router: router)

        // Status
        APIStatusHandler.register(router: router)

        // Camera
        APICameraHandler.register(router: router)

        // Media
        APIMediaHandler.register(router: router)

        // Tasks
        APITaskHandler.register(router: router)

        // Logs
        APILogHandler.register(router: router)

        // Health
        APIHealthHandler.register(router: router)
    }
}
