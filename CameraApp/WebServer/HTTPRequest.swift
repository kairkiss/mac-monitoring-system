import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let queryParameters: [String: String]
    let body: Data?
    let remoteAddress: String

    var bearerToken: String? {
        guard let auth = headers["Authorization"], auth.hasPrefix("Bearer ") else { return nil }
        return String(auth.dropFirst(7))
    }

    var contentType: String? {
        headers["Content-Type"]
    }

    var contentLength: Int {
        headers["Content-Length"].flatMap(Int.init) ?? 0
    }

    var rangeHeader: String? {
        headers["Range"]
    }

    static func parse(from data: String, bodyData: Data?, remoteAddress: String) -> HTTPRequest? {
        let lines = data.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return nil }
        let parts = firstLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0])
        let fullPath = String(parts[1])

        // Parse path and query string
        var path = fullPath
        var queryParams: [String: String] = [:]
        if let qIndex = fullPath.firstIndex(of: "?") {
            path = String(fullPath[fullPath.startIndex..<qIndex])
            let queryString = String(fullPath[fullPath.index(after: qIndex)...])
            for pair in queryString.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    queryParams[String(kv[0])] = String(kv[1]).removingPercentEncoding
                } else if kv.count == 1 {
                    queryParams[String(kv[0])] = ""
                }
            }
        }

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colonIndex = line.firstIndex(of: ":") {
                let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }

        return HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            queryParameters: queryParams,
            body: bodyData,
            remoteAddress: remoteAddress
        )
    }
}
