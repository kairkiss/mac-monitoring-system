import Foundation
import Network

final class HTTPServer {
    private var listener: NWListener?
    private let port: UInt16
    private let bindAddress: String
    let router: WebRouter
    let auditLogger: AuditLogManager

    init(port: UInt16, bindAddress: String, router: WebRouter, auditLogger: AuditLogManager) {
        self.port = port
        self.bindAddress = bindAddress
        self.router = router
        self.auditLogger = auditLogger
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ActivityLogManager.shared.success(.webServer, "Web server listening on \(self.bindAddress):\(self.port)")
            case .failed(let error):
                ActivityLogManager.shared.error(.webServer, "Web server failed", detail: error.localizedDescription)
            case .cancelled:
                ActivityLogManager.shared.info(.webServer, "Web server stopped")
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }

            // Validate remote endpoint is localhost
            if !self.isLocalConnection(connection) {
                connection.cancel()
                return
            }

            let conn = HTTPConnection(
                connection: connection,
                router: self.router,
                auditLogger: self.auditLogger
            )
            conn.start()
        }

        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    var isRunning: Bool {
        listener?.state == .ready
    }

    private func isLocalConnection(_ connection: NWConnection) -> Bool {
        guard let endpoint = connection.currentPath?.remoteEndpoint else { return false }

        switch endpoint {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let addr):
                // 127.0.0.0/8
                let bytes = addr.rawValue
                return bytes[0] == 127
            case .ipv6(let addr):
                // ::1 = loopback
                let loopback = Data([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
                return addr.rawValue == loopback
            default:
                return false
            }
        default:
            return false
        }
    }
}
