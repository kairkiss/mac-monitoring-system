import Foundation
import AuthenticationServices
import Network

final class GoogleDriveAuthManager: NSObject, ObservableObject {
    static let shared = GoogleDriveAuthManager()

    private let kc = KeychainService.shared

    @Published private(set) var userEmail: String = ""
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var needsReconnect: Bool = false

    private var webAuthSession: ASWebAuthenticationSession?
    private var callbackListener: NWListener?

    // OAuth endpoints
    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private static let scope = "https://www.googleapis.com/auth/drive.file"
    // Loopback redirect for desktop apps (Google recommended)
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
            needsReconnect = false // can auto-refresh
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

        // Step 1: Get authorization code via loopback listener
        let (code, redirectURI) = try await requestAuthorizationCode(clientID: clientID)

        // Step 2: Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI
        )

        // Step 3: Persist tokens in Keychain
        try persistTokens(tokenResponse)

        // Step 4: Fetch user info
        try await fetchUserInfo()

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

    // MARK: - OAuth Flow via Loopback

    private func requestAuthorizationCode(clientID: String) async throws -> (String, String) {
        // Start a temporary local HTTP server on a random port
        let port: UInt16 = UInt16.random(in: 49152...65535)
        let redirectBase = "\(Self.redirectURI):\(port)"

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String), Error>) in
            var resumed = false

            do {
                let nwPort = NWEndpoint.Port(rawValue: port)!
                let listener = try NWListener(using: .tcp, on: nwPort)
                self.callbackListener = listener

                listener.newConnectionHandler = { [weak self] connection in
                    guard !resumed else { return }
                    resumed = true

                    connection.start(queue: .global())
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                        guard let data = data,
                              let request = String(data: data, encoding: .utf8) else {
                            connection.cancel()
                            self?.callbackListener?.cancel()
                            self?.callbackListener = nil
                            continuation.resume(throwing: GoogleDriveAuthError.noAuthCode)
                            return
                        }

                        // Extract code from GET /?code=xxx HTTP/1.1
                        let code = self?.extractCode(from: request)

                        // Send response to browser
                        let response = self?.successHTML() ?? "OK"
                        let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(response.count)\r\nConnection: close\r\n\r\n\(response)"
                        connection.send(content: httpResponse.data(using: .utf8), completion: .contentProcessed { _ in
                            connection.cancel()
                        })

                        self?.callbackListener?.cancel()
                        self?.callbackListener = nil

                        if let code = code, !code.isEmpty {
                            continuation.resume(returning: (code, redirectBase))
                        } else {
                            continuation.resume(throwing: GoogleDriveAuthError.noAuthCode)
                        }
                    }
                }

                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        // Build auth URL
                        var components = URLComponents(string: Self.authEndpoint)!
                        components.queryItems = [
                            URLQueryItem(name: "client_id", value: clientID),
                            URLQueryItem(name: "redirect_uri", value: redirectBase),
                            URLQueryItem(name: "response_type", value: "code"),
                            URLQueryItem(name: "scope", value: Self.scope),
                            URLQueryItem(name: "access_type", value: "offline"),
                            URLQueryItem(name: "prompt", value: "consent")
                        ]

                        guard let authURL = components.url else {
                            if !resumed {
                                resumed = true
                                continuation.resume(throwing: GoogleDriveAuthError.invalidURL)
                            }
                            return
                        }

                        // Open browser for auth
                        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: nil) { _, error in
                            // If user cancels, this fires
                            if let error = error {
                                if !resumed {
                                    resumed = true
                                    listener.cancel()
                                    self.callbackListener = nil
                                    continuation.resume(throwing: GoogleDriveAuthError.oauthCancelled)
                                }
                            }
                        }
                        session.presentationContextProvider = self
                        session.prefersEphemeralWebBrowserSession = false
                        self.webAuthSession = session
                        session.start()

                    case .failed(let error):
                        if !resumed {
                            resumed = true
                            continuation.resume(throwing: GoogleDriveAuthError.oauthFailed(error.localizedDescription))
                        }
                    default:
                        break
                    }
                }

                listener.start(queue: .global())
            } catch {
                if !resumed {
                    resumed = true
                    continuation.resume(throwing: GoogleDriveAuthError.oauthFailed(error.localizedDescription))
                }
            }
        }
    }

    private func extractCode(from request: String) -> String? {
        // Parse: GET /?code=xxx&... HTTP/1.1
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
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>Mac监控系统 — Google Drive</title>
        <style>body{font-family:-apple-system,sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#1a1a1a;color:#e0e0e0;}
        .card{background:#242424;padding:40px 48px;border-radius:12px;text-align:center;box-shadow:0 4px 24px rgba(0,0,0,0.3);}
        h1{font-size:20px;margin-bottom:8px;}p{color:#a0a0a0;font-size:14px;}</style></head>
        <body><div class="card"><h1>&#10003; Google Drive 已连接</h1><p>Mac监控系统 — Authorization successful</p><p>请返回应用程序。</p></div></body></html>
        """
    }

    private func exchangeCodeForTokens(code: String, clientID: String, clientSecret: String, redirectURI: String) async throws -> GoogleDriveTokenResponse {
        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
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

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveAuthError.tokenExchangeFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        return try JSONDecoder().decode(GoogleDriveTokenResponse.self, from: data)
    }

    private func refreshAccessToken(clientID: String, clientSecret: String) async throws -> String {
        guard let refreshToken = try? kc.read(service: kc.service, account: kc.googleDriveRefreshTokenAccount),
              !refreshToken.isEmpty else {
            throw GoogleDriveAuthError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
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

        let tokenResponse = try JSONDecoder().decode(GoogleDriveRefreshResponse.self, from: data)

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

        let url = URL(string: "https://www.googleapis.com/drive/v3/about?fields=user")!
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
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
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
    case noAuthCode
    case invalidURL
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Google API Client ID and Secret are required. Configure in Settings > Storage Providers > Google Drive."
        case .oauthFailed(let detail): return "OAuth failed: \(detail)"
        case .oauthCancelled: return "Sign-in was cancelled. Please try again."
        case .noAuthCode: return "No authorization code received. Please try again."
        case .invalidURL: return "Invalid OAuth URL. Check your Client ID."
        case .tokenExchangeFailed: return "Token exchange failed. Check your Client ID and Secret."
        case .tokenRefreshFailed: return "Token refresh failed. Please sign in again."
        case .notAuthenticated: return "Not authenticated with Google Drive. Please sign in."
        }
    }
}
