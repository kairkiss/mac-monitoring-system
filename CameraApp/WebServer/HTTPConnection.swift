import Foundation
import Network

final class HTTPConnection {
    let connection: NWConnection
    let router: WebRouter
    let auditLogger: AuditLogManager?
    private var buffer = Data()
    private var headerParsed = false
    private var contentLength = 0
    private var headerData = ""

    init(connection: NWConnection, router: WebRouter, auditLogger: AuditLogManager?) {
        self.connection = connection
        self.router = router
        self.auditLogger = auditLogger
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.readData()
            case .failed, .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    private func readData() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data, !data.isEmpty else {
                self?.connection.cancel()
                return
            }

            self.buffer.append(data)

            if !self.headerParsed {
                // Look for end of headers
                if let range = self.buffer.range(of: Data("\r\n\r\n".utf8)) {
                    self.headerParsed = true
                    self.headerData = String(data: self.buffer[self.buffer.startIndex..<range.lowerBound], encoding: .utf8) ?? ""
                    let bodyStart = range.upperBound

                    // Parse content-length from headers
                    let headerLines = self.headerData.components(separatedBy: "\r\n")
                    for line in headerLines {
                        if line.lowercased().hasPrefix("content-length:") {
                            let val = line.dropFirst(15).trimmingCharacters(in: .whitespaces)
                            self.contentLength = Int(val) ?? 0
                        }
                    }

                    // Check if we have all body data
                    let bodyData = self.buffer[bodyStart...]
                    if bodyData.count >= self.contentLength {
                        let body = Data(bodyData.prefix(self.contentLength))
                        self.handleRequest(bodyData: body)
                    } else {
                        // Need more body data
                        self.readData()
                    }
                } else {
                    // Headers not complete yet
                    if self.buffer.count > 8192 {
                        // Header too large
                        self.sendError(status: 413, message: "Header Too Large")
                        return
                    }
                    self.readData()
                }
            } else {
                // Already parsed headers, waiting for body
                let bodyData = self.buffer
                if bodyData.count >= self.contentLength {
                    let body = Data(bodyData.prefix(self.contentLength))
                    self.handleRequest(bodyData: body)
                } else {
                    self.readData()
                }
            }

            if isComplete {
                self.connection.cancel()
            }
        }
    }

    private func handleRequest(bodyData: Data) {
        let remoteAddr = connection.endpoint.debugDescription
        guard let request = HTTPRequest.parse(from: headerData, bodyData: bodyData, remoteAddress: remoteAddr) else {
            sendError(status: 400, message: "Bad Request")
            return
        }

        let startTime = Date()
        let response = router.handle(request: request)
        let duration = Date().timeIntervalSince(startTime)

        sendResponse(response)

        // Audit log
        auditLogger?.log(
            method: request.method,
            path: request.path,
            status: response.status,
            duration: duration,
            remoteAddress: request.remoteAddress,
            user: nil
        )
    }

    private func sendResponse(_ response: HTTPResponse) {
        let data = response.serialized()
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
        })
    }

    private func sendError(status: Int, message: String) {
        let response = HTTPResponse.error(message, status: status)
        sendResponse(response)
    }
}
