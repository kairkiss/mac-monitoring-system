import Foundation

struct HTTPResponse {
    var status: Int
    var statusText: String
    var headers: [String: String]
    var body: Data

    init(status: Int, statusText: String, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.statusText = statusText
        self.headers = headers
        self.body = body
    }

    static func json(_ object: Any, status: Int = 200) -> HTTPResponse {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            return HTTPResponse(status: 500, statusText: "Internal Server Error")
        }
        return HTTPResponse(
            status: status,
            statusText: statusText(for: status),
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }

    static func jsonString(_ text: String, status: Int = 200) -> HTTPResponse {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let json = "\"\(escaped)\""
        guard let data = json.data(using: .utf8) else {
            return HTTPResponse(status: 500, statusText: "Internal Server Error")
        }
        return HTTPResponse(
            status: status,
            statusText: statusText(for: status),
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: data
        )
    }

    static func html(_ html: String, status: Int = 200) -> HTTPResponse {
        let data = html.data(using: .utf8) ?? Data()
        return HTTPResponse(
            status: status,
            statusText: statusText(for: status),
            headers: ["Content-Type": "text/html; charset=utf-8"],
            body: data
        )
    }

    static func error(_ message: String, status: Int = 400) -> HTTPResponse {
        return json(["error": message], status: status)
    }

    static func redirect(_ location: String) -> HTTPResponse {
        return HTTPResponse(
            status: 302,
            statusText: "Found",
            headers: ["Location": location]
        )
    }

    static func data(_ data: Data, contentType: String) -> HTTPResponse {
        return HTTPResponse(
            status: 200,
            statusText: "OK",
            headers: ["Content-Type": contentType, "Content-Length": "\(data.count)"],
            body: data
        )
    }

    static func ok(_ message: String = "ok") -> HTTPResponse {
        return json(["status": message])
    }

    func serialized() -> Data {
        var head = "HTTP/1.1 \(status) \(statusText)\r\n"
        var hdrs = headers
        hdrs["Content-Length"] = "\(body.count)"
        hdrs["Connection"] = "close"
        for (key, value) in hdrs.sorted(by: { $0.key < $1.key }) {
            head += "\(key): \(value)\r\n"
        }
        head += "\r\n"
        var result = Data(head.utf8)
        result.append(body)
        return result
    }

    private static func statusText(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        case 503: return "Service Unavailable"
        default: return "Unknown"
        }
    }
}
