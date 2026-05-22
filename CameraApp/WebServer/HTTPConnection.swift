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
    private var handled = false

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
            case .failed(let error):
                NSLog("[HTTPConnection] connection failed: \(error)")
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
        // Also try to read immediately in case connection is already ready
        readData()
    }

    private func readData() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                NSLog("[HTTPConnection] receive error: \(error)")
                self.connection.cancel()
                return
            }

            guard let data, !data.isEmpty else {
                // Connection closed or no data — send whatever we have if headers are complete
                if self.headerParsed && !self.handled {
                    let body = Data(self.buffer.prefix(self.contentLength))
                    self.handleRequest(bodyData: body)
                } else if !self.handled {
                    self.connection.cancel()
                }
                return
            }

            self.buffer.append(data)

            if !self.headerParsed {
                if let range = self.buffer.range(of: Data("\r\n\r\n".utf8)) {
                    self.headerParsed = true
                    self.headerData = String(data: self.buffer[self.buffer.startIndex..<range.lowerBound], encoding: .utf8) ?? ""
                    let bodyStart = range.upperBound

                    let headerLines = self.headerData.components(separatedBy: "\r\n")
                    for line in headerLines {
                        if line.lowercased().hasPrefix("content-length:") {
                            let val = line.dropFirst(15).trimmingCharacters(in: .whitespaces)
                            self.contentLength = Int(val) ?? 0
                        }
                    }

                    let bodyData = self.buffer[bodyStart...]
                    if bodyData.count >= self.contentLength {
                        let body = Data(bodyData.prefix(self.contentLength))
                        self.handleRequest(bodyData: body)
                    } else {
                        self.readData()
                    }
                } else {
                    if self.buffer.count > 8192 {
                        self.sendError(status: 413, message: "Header Too Large")
                        return
                    }
                    self.readData()
                }
            } else {
                let bodyData = self.buffer
                if bodyData.count >= self.contentLength {
                    let body = Data(bodyData.prefix(self.contentLength))
                    self.handleRequest(bodyData: body)
                } else {
                    self.readData()
                }
            }
        }
    }

    private func handleRequest(bodyData: Data) {
        guard !handled else { return }
        handled = true

        let remoteAddr = connection.endpoint.debugDescription
        guard let request = HTTPRequest.parse(from: headerData, bodyData: bodyData, remoteAddress: remoteAddr) else {
            sendError(status: 400, message: "Bad Request")
            return
        }

        let startTime = Date()
        let response = router.handle(request: request)
        let duration = Date().timeIntervalSince(startTime)

        sendResponse(response)

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
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                NSLog("[HTTPConnection] send error: \(error)")
            }
            self?.connection.cancel()
        })
    }

    private func sendError(status: Int, message: String) {
        guard !handled else { return }
        handled = true
        let response = HTTPResponse.error(message, status: status)
        sendResponse(response)
    }
}
