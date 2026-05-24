import Foundation
import AuthenticationServices
import Network
import AppKit

// Thread-safe single-resume guard for continuations
private final class ContinuationGuard {
    private let lock = NSLock()
    private var resumed = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if resumed { return false }
        resumed = true
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

    // Strong references to prevent deallocation during OAuth flow
    private var webAuthSession: ASWebAuthenticationSession?
    private var callbackListener: NWListener?

    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private static let scope = "https://www.googleapis.com/auth/drive.file"
    private static let redirectURI = "http://127.0.0.1"

    private override init() {
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

        let (code, redirectURI) = try await requestAuthorizationCode(clientID: clientID)

        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI
        )

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

    // MARK: - OAuth Flow

    private func requestAuthorizationCode(clientID: String) async throws -> (String, String) {
        for attempt in 0..<5 {
            let port = UInt16.random(in: 49152...65535)
            do {
                return try await doOAuthOnPort(port: port, clientID: clientID)
            } catch let error as GoogleDriveAuthError {
                if case .listenerFailed = error {
                    ActivityLogManager.shared.warning(.upload, "OAuth port \(port) unavailable (attempt \(attempt + 1)), retrying...")
                    continue
                }
                throw error
            }
        }
        throw GoogleDriveAuthError.listenerFailed("Could not bind to any port after 5 attempts")
    }

    private func doOAuthOnPort(port: UInt16, clientID: String) async throws -> (String, String) {
        let redirectBase = "\(Self.redirectURI):\(port)"

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw GoogleDriveAuthError.oauthFailed("Invalid port number")
        }

        // Pre-build auth URL
        guard var components = URLComponents(string: Self.authEndpoint) else {
            throw GoogleDriveAuthError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectBase),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let authURL = components.url else {
            throw GoogleDriveAuthError.invalidURL
        }

        // Pre-create listener
        let listener: NWListener
        do {
            listener = try NWListener(using: .tcp, on: nwPort)
        } catch {
            throw GoogleDriveAuthError.listenerFailed(error.localizedDescription)
        }
        self.callbackListener = listener

        // Use continuation with timeout
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String), Error>) in
            let guard_ = ContinuationGuard()
            var timeoutItem: DispatchWorkItem?

            // Timeout: resume with error if nothing happens in 90 seconds
            let item = DispatchWorkItem { [weak self] in
                if guard_.tryResume() {
                    self?.cleanupListener()
                    continuation.resume(throwing: GoogleDriveAuthError.oauthTimedOut)
                }
            }
            timeoutItem = item
            DispatchQueue.global().asyncAfter(deadline: .now() + 90, execute: item)

            // Connection handler: receives the OAuth code from the browser redirect
            listener.newConnectionHandler = { [weak self] connection in
                guard guard_.tryResume() else { return }
                timeoutItem?.cancel()

                connection.start(queue: .global())
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    guard let data = data,
                          let request = String(data: data, encoding: .utf8) else {
                        connection.cancel()
                        self?.cleanupListener()
                        continuation.resume(throwing: GoogleDriveAuthError.noAuthCode)
                        return
                    }

                    let code = self?.extractCode(from: request)

                    if let response = self?.successHTML() {
                        let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(response.utf8.count)\r\nConnection: close\r\n\r\n\(response)"
                        connection.send(content: httpResponse.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                    } else {
                        connection.cancel()
                    }

                    self?.cleanupListener()

                    if let code = code, !code.isEmpty {
                        continuation.resume(returning: (code, redirectBase))
                    } else {
                        continuation.resume(throwing: GoogleDriveAuthError.noAuthCode)
                    }
                }
            }

            // State handler: opens the auth page when listener is ready
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: nil) { _, error in
                            if error != nil {
                                if guard_.tryResume() {
                                    timeoutItem?.cancel()
                                    self?.cleanupListener()
                                    continuation.resume(throwing: GoogleDriveAuthError.oauthCancelled)
                                }
                            }
                        }
                        session.presentationContextProvider = self
                        session.prefersEphemeralWebBrowserSession = false
                        self?.webAuthSession = session
                        session.start()
                    }

                case .failed(let error):
                    if guard_.tryResume() {
                        timeoutItem?.cancel()
                        self?.cleanupListener()
                        continuation.resume(throwing: GoogleDriveAuthError.listenerFailed(error.localizedDescription))
                    }
                case .cancelled:
                    if guard_.tryResume() {
                        timeoutItem?.cancel()
                        self?.cleanupListener()
                        continuation.resume(throwing: GoogleDriveAuthError.oauthCancelled)
                    }
                case .waiting:
                    break // port may be in use, will timeout if stuck
                default:
                    break
                }
            }

            listener.start(queue: .global())
        }
    }

    private func cleanupListener() {
        callbackListener?.cancel()
        callbackListener = nil
    }

    private func extractCode(from request: String) -> String? {
        guard let firstLine = request.components(separatedBy: "\r\n").first,
              let queryStart = firstLine.firstIndex(of: "?"),
              let queryEnd = firstLine.firstIndex(of: " ") else {
            return nil
        }
        let queryString = String(firstLine[firstLine.index(after: queryStart)..<queryEnd])
        let pairs = queryString.components(separatedBy: "&")
        for pair in pairs {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2 && kv[0] == "code" {
                return kv[1].removingPercentEncoding
            }
        }
        return nil
    }

    private func successHTML() -> String {
        return """
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>MacMonitor — Google Drive</title>
        <style>body{font-family:-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#1a1a1a;color:#e0e0e0;}
        .card{background:#242424;padding:40px 48px;border-radius:12px;text-align:center;box-shadow:0 4px 24px rgba(0,0,0,0.3);}
        h1{font-size:20px;margin-bottom:8px;}p{color:#a0a0a0;font-size:14px;}</style></head>
        <body><div class="card"><h1>&#10003; Google Drive Connected</h1><p>MacMonitor — Authorization successful</p><p>Return to the application.</p></div></body></html>
        """
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, clientID: String, clientSecret: String, redirectURI: String) async throws -> GoogleDriveTokenResponse {
        guard let url = URL(string: Self.tokenEndpoint) else {
            throw GoogleDriveAuthError.tokenExchangeFailed("Invalid token endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveAuthError.tokenExchangeFailed("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw GoogleDriveAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode)")
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
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
            let formatter = ISO8601DateFormatter()
            kc.googleDriveTokenExpiry = formatter.string(from: expiry)
        }

        await MainActor.run { needsReconnect = false }
        ActivityLogManager.shared.info(.upload, "Google Drive token refreshed")
        return tokenResponse.accessToken
    }

    // MARK: - User Info

    private func fetchUserInfo() async throws {
        guard let token = try? kc.read(service: kc.service, account: kc.googleDriveAccessTokenAccount),
              !token.isEmpty else { return }

        guard let url = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let user = json["user"] as? [String: Any],
           let email = user["emailAddress"] as? String {
            kc.googleDriveUserEmail = email
            await MainActor.run { self.userEmail = email }
        }
    }

    // MARK: - Helpers

    private func isTokenExpired() -> Bool {
        guard let expiryStr = try? kc.read(service: kc.service, account: kc.googleDriveTokenExpiryAccount),
              !expiryStr.isEmpty else {
            return true
        }
        let formatter = ISO8601DateFormatter()
        guard let expiry = formatter.date(from: expiryStr) else {
            return true
        }
        return Date() >= expiry
    }

    private func persistTokens(_ response: GoogleDriveTokenResponse) throws {
        kc.googleDriveAccessToken = response.accessToken
        if let refresh = response.refreshToken {
            kc.googleDriveRefreshToken = refresh
        }
        if let expiresIn = response.expiresIn {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            let formatter = ISO8601DateFormatter()
            kc.googleDriveTokenExpiry = formatter.string(from: expiry)
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleDriveAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for window in NSApplication.shared.windows {
            if window.isVisible { return window }
        }
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
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

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Google Drive is not configured. Please enter Client ID and Client Secret."
        case .oauthFailed(let detail): return "OAuth failed: \(detail)"
        case .oauthCancelled: return "Sign-in was cancelled. Please try again."
        case .oauthTimedOut: return "Sign-in timed out. The browser may not have redirected back to the app. Please try again."
        case .noAuthCode: return "No authorization code received. Please try again."
        case .invalidURL: return "Invalid OAuth URL. Check your Client ID."
        case .tokenExchangeFailed: return "Token exchange failed. Check your Client ID and Secret."
        case .tokenRefreshFailed: return "Token refresh failed. Please sign in again."
        case .notAuthenticated: return "Not authenticated with Google Drive. Please sign in."
        case .listenerFailed(let detail): return "Local callback listener failed: \(detail)"
        }
    }
}
