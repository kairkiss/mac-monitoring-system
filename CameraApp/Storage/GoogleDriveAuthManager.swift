import Foundation
import Network
import AppKit
import CryptoKit

// Thread-safe single-resume guard
private final class Once {
    private let lock = NSLock()
    private var fired = false
    func call() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if fired { return false }
        fired = true
        return true
    }
}

final class GoogleDriveAuthManager: NSObject, ObservableObject {
    static let shared = GoogleDriveAuthManager()

    private let kc = KeychainService.shared

    @Published private(set) var userEmail: String = ""
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var needsReconnect: Bool = false

    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private static let scope = "https://www.googleapis.com/auth/drive.file"
    private static let redirectURI = "http://127.0.0.1"

    override init() {
        super.init()
        loadState()
    }

    private func loadState() {
        userEmail = kc.googleDriveUserEmail
        let hasTokens = !kc.googleDriveAccessToken.isEmpty && !kc.googleDriveRefreshToken.isEmpty
        isAuthenticated = hasTokens && !isTokenExpired()
        if hasTokens && isTokenExpired() && !kc.googleDriveRefreshToken.isEmpty {
            needsReconnect = false
        } else if hasTokens && isTokenExpired() {
            needsReconnect = true
        }
    }

    // MARK: - Public API

    func authenticate(clientID: String, clientSecret: String) async throws {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw GoogleDriveAuthError.missingCredentials
        }

        await MainActor.run { isAuthenticating = true }
        defer { Task { @MainActor in isAuthenticating = false } }

        // Step 1: Get auth code via system browser + loopback listener
        let (code, redirectURI, codeVerifier) = try await getAuthorizationCode(clientID: clientID)

        // Step 2: Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI,
            codeVerifier: codeVerifier
        )

        // Step 3: Persist
        try persistTokens(tokenResponse)
        try? await fetchUserInfo()

        await MainActor.run {
            isAuthenticated = true
            needsReconnect = false
        }
        ActivityLogManager.shared.success(.upload, "Google Drive authenticated")
    }

    func signOut() {
        kc.googleDriveAccessToken = ""
        kc.googleDriveRefreshToken = ""
        kc.googleDriveTokenExpiry = ""
        kc.googleDriveUserEmail = ""
        kc.googleDriveRootFolderID = ""
        kc.googleDriveClientSecret = ""

        Task { @MainActor in
            isAuthenticated = false
            needsReconnect = false
            userEmail = ""
        }
        ActivityLogManager.shared.info(.upload, "Google Drive signed out")
    }

    func getValidAccessToken(clientID: String, clientSecret: String) async throws -> String {
        if !isTokenExpired() && !kc.googleDriveAccessToken.isEmpty {
            return kc.googleDriveAccessToken
        }
        guard !kc.googleDriveRefreshToken.isEmpty else {
            await MainActor.run { needsReconnect = true }
            throw GoogleDriveAuthError.notAuthenticated
        }
        do {
            return try await refreshAccessToken(clientID: clientID, clientSecret: clientSecret)
        } catch {
            await MainActor.run { needsReconnect = true }
            throw GoogleDriveAuthError.tokenRefreshFailed
        }
    }

    // MARK: - OAuth: System Browser + Loopback Listener
    //
    // Uses NSWorkspace.shared.open() to open the system browser (not ASWebAuthenticationSession).
    // A standalone NWListener on a random port receives the OAuth callback.
    // Security: PKCE (S256) + state parameter prevent code interception and CSRF.

    private func getAuthorizationCode(clientID: String) async throws -> (String, String, String) {
        for attempt in 1...5 {
            let port = UInt16.random(in: 49152...65535)
            do {
                return try await doOAuthOnPort(port: port, clientID: clientID, attempt: attempt)
            } catch let error as GoogleDriveAuthError {
                if case .listenerFailed = error {
                    ActivityLogManager.shared.warning(.upload, "OAuth port \(port) unavailable (attempt \(attempt)), retrying...")
                    continue
                }
                throw error
            }
        }
        throw GoogleDriveAuthError.listenerFailed("Could not start local server after 5 attempts")
    }

    private func doOAuthOnPort(port: UInt16, clientID: String, attempt: Int) async throws -> (String, String, String) {
        let redirectBase = "\(Self.redirectURI):\(port)"

        // Generate PKCE + state
        let codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.codeChallenge(from: codeVerifier)
        let state = Self.generateState()

        // Build auth URL
        guard var components = URLComponents(string: Self.authEndpoint) else {
            throw GoogleDriveAuthError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectBase),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authURL = components.url else {
            throw GoogleDriveAuthError.invalidURL
        }

        // Create listener
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw GoogleDriveAuthError.listenerFailed("Invalid port")
        }
        let listener: NWListener
        do {
            listener = try NWListener(using: .tcp, on: nwPort)
        } catch {
            throw GoogleDriveAuthError.listenerFailed(error.localizedDescription)
        }

        ActivityLogManager.shared.info(.upload, "Google Drive OAuth started (attempt \(attempt), port \(port))")

        // Continuation: only the listener callback can resume it
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String, String), Error>) in
            let once = Once()
            var listenerRef: NWListener? = listener

            // Timeout after 120s
            let timeout = DispatchWorkItem {
                if once.call() {
                    listenerRef?.cancel()
                    listenerRef = nil
                    cont.resume(throwing: GoogleDriveAuthError.oauthTimedOut)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeout)

            // Connection handler: receives the redirect from the browser
            listener.newConnectionHandler = { connection in
                connection.start(queue: .global())
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                    guard let data = data, let raw = String(data: data, encoding: .utf8) else {
                        connection.cancel()
                        return // don't consume Once — wait for valid connection
                    }

                    // Parse HTTP request to validate it's a real OAuth callback
                    let params = Self.extractCallbackParams(from: raw)
                    let hasCodeAndState = params.code != nil && params.state != nil
                    let hasErrorAndState = params.error != nil && params.state != nil

                    guard hasCodeAndState || hasErrorAndState else {
                        // Not an OAuth callback (favicon, probe, etc.) — reject silently
                        let resp = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                        connection.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                        return // don't consume Once — wait for valid OAuth callback
                    }

                    // Valid OAuth callback — consume Once
                    guard once.call() else {
                        connection.cancel()
                        return
                    }
                    timeout.cancel()
                    listenerRef?.cancel()
                    listenerRef = nil

                    // Send success response to browser
                    if let html = Self.successHTML() {
                        let resp = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
                        connection.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    } else {
                        connection.cancel()
                    }

                    // Handle error from Google
                    if let error = params.error {
                        let mapped = Self.mapOAuthError(error)
                        cont.resume(throwing: mapped)
                        return
                    }

                    // Validate state
                    guard params.state == state else {
                        cont.resume(throwing: GoogleDriveAuthError.stateMismatch)
                        return
                    }

                    // Return code
                    if let code = params.code, !code.isEmpty {
                        cont.resume(returning: (code, redirectBase, codeVerifier))
                    } else {
                        cont.resume(throwing: GoogleDriveAuthError.noAuthCode)
                    }
                }
            }

            // State handler
            listener.stateUpdateHandler = { listenerState in
                switch listenerState {
                case .ready:
                    DispatchQueue.main.async {
                        NSWorkspace.shared.open(authURL)
                    }
                case .failed(let error):
                    if once.call() {
                        timeout.cancel()
                        listenerRef?.cancel()
                        listenerRef = nil
                        cont.resume(throwing: GoogleDriveAuthError.listenerFailed(error.localizedDescription))
                    }
                case .cancelled:
                    if once.call() {
                        timeout.cancel()
                        cont.resume(throwing: GoogleDriveAuthError.oauthCancelled)
                    }
                default:
                    break
                }
            }

            listener.start(queue: .global())
        }
    }

    // MARK: - PKCE

    private static func generateCodeVerifier() -> String {
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var buffer = [UInt8](repeating: 0, count: 128)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return buffer.map { charset[Int($0) % charset.count] }.reduce(into: "") { $0.append($1) }
    }

    private static func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func generateState() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return buffer.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Callback Parameter Extraction

    private struct CallbackParams {
        let code: String?
        let state: String?
        let error: String?
    }

    private static func extractCallbackParams(from raw: String) -> CallbackParams {
        guard let firstLine = raw.components(separatedBy: "\r\n").first else {
            return CallbackParams(code: nil, state: nil, error: nil)
        }
        guard let qStart = firstLine.firstIndex(of: "?"),
              let qEnd = firstLine[firstLine.index(after: qStart)...].firstIndex(of: " ") else {
            return CallbackParams(code: nil, state: nil, error: nil)
        }
        let query = String(firstLine[firstLine.index(after: qStart)..<qEnd])
        var code: String?
        var state: String?
        var error: String?
        for pair in query.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0]
            let value = kv[1].removingPercentEncoding
            switch key {
            case "code": code = value
            case "state": state = value
            case "error": error = value
            default: break
            }
        }
        return CallbackParams(code: code, state: state, error: error)
    }

    private static func mapOAuthError(_ error: String) -> GoogleDriveAuthError {
        switch error {
        case "access_denied": return .accessDenied
        case "redirect_uri_mismatch": return .redirectURIMismatch
        case "invalid_client": return .invalidClient
        case "invalid_scope": return .invalidScope
        default: return .oauthFailed(error)
        }
    }

    private static func successHTML() -> String? {
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>MacMonitor — Google Drive</title>
        <style>body{font-family:-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#1a1a1a;color:#e0e0e0;}
        .card{background:#242424;padding:40px 48px;border-radius:12px;text-align:center;box-shadow:0 4px 24px rgba(0,0,0,0.3);}
        h1{font-size:20px;margin-bottom:8px;}p{color:#a0a0a0;font-size:14px;}</style></head>
        <body><div class="card"><h1>&#10003; Google Drive Connected</h1><p>MacMonitor — Authorization successful</p><p>Return to the application.</p></div></body></html>
        """
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, clientID: String, clientSecret: String, redirectURI: String, codeVerifier: String) async throws -> GoogleDriveTokenResponse {
        guard let url = URL(string: Self.tokenEndpoint) else {
            throw GoogleDriveAuthError.tokenExchangeFailed("Invalid token endpoint")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        request.httpBody = Self.formEncode(body).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleDriveAuthError.tokenExchangeFailed("No response")
        }
        guard http.statusCode == 200 else {
            throw Self.mapTokenEndpointError(data: data, statusCode: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(GoogleDriveTokenResponse.self, from: data)
        } catch {
            throw GoogleDriveAuthError.tokenExchangeFailed("Invalid token response")
        }
    }

    private func refreshAccessToken(clientID: String, clientSecret: String) async throws -> String {
        guard let refreshToken = try? kc.read(service: kc.service, account: kc.googleDriveRefreshTokenAccount),
              !refreshToken.isEmpty else {
            throw GoogleDriveAuthError.notAuthenticated
        }
        guard let url = URL(string: Self.tokenEndpoint) else {
            throw GoogleDriveAuthError.tokenRefreshFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = Self.formEncode(body).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            await MainActor.run { needsReconnect = true }
            throw GoogleDriveAuthError.tokenRefreshFailed
        }
        let tokenResponse: GoogleDriveRefreshResponse
        do {
            tokenResponse = try JSONDecoder().decode(GoogleDriveRefreshResponse.self, from: data)
        } catch {
            await MainActor.run { needsReconnect = true }
            throw GoogleDriveAuthError.tokenRefreshFailed
        }
        kc.googleDriveAccessToken = tokenResponse.accessToken
        if let expiresIn = tokenResponse.expiresIn {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            kc.googleDriveTokenExpiry = ISO8601DateFormatter().string(from: expiry)
        }
        await MainActor.run { needsReconnect = false }
        ActivityLogManager.shared.info(.upload, "Google Drive token refreshed")
        return tokenResponse.accessToken
    }

    // MARK: - Form Encoding

    private static func formEncode(_ dict: [String: String]) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return dict.map { key, value in
            let ek = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let ev = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(ek)=\(ev)"
        }.joined(separator: "&")
    }

    // MARK: - Token Endpoint Error Parsing

    private static func mapTokenEndpointError(data: Data, statusCode: Int) -> GoogleDriveAuthError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorCode = json["error"] as? String {
            let desc = json["error_description"] as? String
            switch errorCode {
            case "access_denied": return .accessDenied
            case "redirect_uri_mismatch": return .redirectURIMismatch
            case "invalid_client": return .invalidClient
            case "invalid_scope": return .invalidScope
            default: return .tokenExchangeFailed(desc ?? "HTTP \(statusCode): \(errorCode)")
            }
        }
        return .tokenExchangeFailed("HTTP \(statusCode)")
    }

    // MARK: - User Info

    private func fetchUserInfo() async throws {
        guard let token = try? kc.read(service: kc.service, account: kc.googleDriveAccessTokenAccount),
              !token.isEmpty else { return }
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let user = json["user"] as? [String: Any],
           let email = user["emailAddress"] as? String {
            kc.googleDriveUserEmail = email
            await MainActor.run { self.userEmail = email }
        }
    }

    // MARK: - Helpers

    private func isTokenExpired() -> Bool {
        guard let s = try? kc.read(service: kc.service, account: kc.googleDriveTokenExpiryAccount), !s.isEmpty,
              let d = ISO8601DateFormatter().date(from: s) else { return true }
        return Date() >= d
    }

    private func persistTokens(_ r: GoogleDriveTokenResponse) throws {
        kc.googleDriveAccessToken = r.accessToken
        if let t = r.refreshToken { kc.googleDriveRefreshToken = t }
        if let e = r.expiresIn {
            kc.googleDriveTokenExpiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(e)))
        }
    }
}

// MARK: - Models

struct GoogleDriveTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let scope: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

struct GoogleDriveRefreshResponse: Codable {
    let accessToken: String
    let expiresIn: Int?
    let tokenType: String?
    let scope: String?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

enum GoogleDriveAuthError: LocalizedError {
    case missingCredentials
    case oauthFailed(String)
    case oauthCancelled
    case oauthTimedOut
    case noAuthCode
    case invalidURL
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case notAuthenticated
    case listenerFailed(String)
    case stateMismatch
    case accessDenied
    case redirectURIMismatch
    case invalidClient
    case invalidScope

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Google Drive is not configured. Please enter Client ID and Client Secret."
        case .oauthFailed(let d): return "OAuth failed: \(d)"
        case .oauthCancelled: return "Sign-in was cancelled."
        case .oauthTimedOut: return "Sign-in timed out. Please try again."
        case .noAuthCode: return "No authorization code received. Please try again."
        case .invalidURL: return "Invalid OAuth URL. Check your Client ID."
        case .tokenExchangeFailed(let d): return "Token exchange failed: \(d)"
        case .tokenRefreshFailed: return "Token refresh failed. Please sign in again."
        case .notAuthenticated: return "Not authenticated with Google Drive. Please sign in."
        case .listenerFailed(let d): return "Could not start local server: \(d)"
        case .stateMismatch: return "Security verification failed (state mismatch). Please try again."
        case .accessDenied: return "Access was denied. Please grant permission to continue."
        case .redirectURIMismatch: return "Redirect URI mismatch. Check your OAuth configuration."
        case .invalidClient: return "Invalid client. Check your Client ID."
        case .invalidScope: return "Invalid scope. Check your OAuth configuration."
        }
    }
}
