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
    private var selfRef: HTTPConnection?  // prevent deallocation while active

    init(connection: NWConnection, router: WebRouter, auditLogger: AuditLogManager?) {
        self.connection = connection
        self.router = router
        self.auditLogger = auditLogger
    }

    func start() {
        selfRef = self  // keep alive until connection closes
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.readData()
            case .failed(let error):
                NSLog("[HTTPConnection] failed: \(error)")
                self?.selfRef = nil
            case .cancelled:
                self?.selfRef = nil
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
        // In case connection is already ready before handler is assigned
        readData()
    }

    private func readData() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                NSLog("[HTTPConnection] receive error: \(error)")
                self.cleanup()
                return
            }

            guard let data, !data.isEmpty else {
                if self.headerParsed && !self.handled {
                    let body = Data(self.buffer.prefix(self.contentLength))
                    self.handleRequest(bodyData: body)
                } else {
                    self.cleanup()
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
            user: request.sessionUsername
        )
    }

    private func sendResponse(_ response: HTTPResponse) {
        let data = response.serialized()
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            self?.cleanup()
        })
    }

    private func sendError(status: Int, message: String) {
        guard !handled else { return }
        handled = true
        let response = HTTPResponse.error(message, status: status)
        sendResponse(response)
    }

    private func cleanup() {
        connection.cancel()
        selfRef = nil
    }
}
