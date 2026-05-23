import Foundation
import AuthenticationServices

final class GoogleDriveAuthManager: NSObject, ObservableObject {
    static let shared = GoogleDriveAuthManager()

    private let kc = KeychainService.shared

    @Published private(set) var userEmail: String = ""
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isAuthenticating: Bool = false

    private var webAuthSession: ASWebAuthenticationSession?

    // OAuth endpoints
    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private static let scope = "https://www.googleapis.com/auth/drive.file"
    private static let redirectURI = "com.googleusercontent.apps.XXXXXXXXXXXXXX:/oauth2redirect"

    private override init() {
        super.init()
        loadState()
    }

    private func loadState() {
        userEmail = kc.googleDriveUserEmail
        isAuthenticated = !kc.googleDriveAccessToken.isEmpty && !isTokenExpired()
    }

    // MARK: - Public API

    func authenticate(clientID: String, clientSecret: String) async throws {
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            throw GoogleDriveAuthError.missingCredentials
        }

        await MainActor.run { isAuthenticating = true }
        defer { Task { @MainActor in isAuthenticating = false } }

        // Step 1: Get authorization code
        let code = try await requestAuthorizationCode(clientID: clientID)

        // Step 2: Exchange code for tokens
        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            clientID: clientID,
            clientSecret: clientSecret
        )

        // Step 3: Persist tokens in Keychain
        try persistTokens(tokenResponse)

        // Step 4: Fetch user info
        try await fetchUserInfo()

        await MainActor.run { isAuthenticated = true }
        ActivityLogManager.shared.success(.upload, "Google Drive authenticated: \(userEmail)")
    }

    func signOut() {
        kc.googleDriveAccessToken = ""
        kc.googleDriveRefreshToken = ""
        kc.googleDriveTokenExpiry = ""
        kc.googleDriveUserEmail = ""
        kc.googleDriveRootFolderID = ""
        SettingsStore.shared.googleDriveFolderID = ""

        Task { @MainActor in
            isAuthenticated = false
            userEmail = ""
        }
        ActivityLogManager.shared.info(.upload, "Google Drive signed out")
    }

    func getValidAccessToken(clientID: String, clientSecret: String) async throws -> String {
        if !isTokenExpired() && !kc.googleDriveAccessToken.isEmpty {
            return kc.googleDriveAccessToken
        }

        guard !kc.googleDriveRefreshToken.isEmpty else {
            throw GoogleDriveAuthError.notAuthenticated
        }

        return try await refreshAccessToken(clientID: clientID, clientSecret: clientSecret)
    }

    // MARK: - OAuth Flow

    private func requestAuthorizationCode(clientID: String) async throws -> String {
        var components = URLComponents(string: Self.authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw GoogleDriveAuthError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.googleusercontent.apps.XXXXXXXXXXXXXX") { callbackURL, error in
                guard !resumed else { return }
                resumed = true

                if let error = error {
                    continuation.resume(throwing: GoogleDriveAuthError.oauthFailed(error.localizedDescription))
                    return
                }

                guard let callbackURL = callbackURL,
                      let codeComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = codeComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: GoogleDriveAuthError.noAuthCode)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }
    }

    private func exchangeCodeForTokens(code: String, clientID: String, clientSecret: String) async throws -> GoogleDriveTokenResponse {
        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw GoogleDriveAuthError.tokenExchangeFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(body)")
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
            throw GoogleDriveAuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(GoogleDriveRefreshResponse.self, from: data)

        kc.googleDriveAccessToken = tokenResponse.accessToken
        if let expiresIn = tokenResponse.expiresIn {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            let formatter = ISO8601DateFormatter()
            kc.googleDriveTokenExpiry = formatter.string(from: expiry)
        }

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
    case noAuthCode
    case invalidURL
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Google API client ID and secret are required"
        case .oauthFailed(let detail): return "OAuth failed: \(detail)"
        case .noAuthCode: return "No authorization code received"
        case .invalidURL: return "Invalid OAuth URL"
        case .tokenExchangeFailed(let detail): return "Token exchange failed: \(detail)"
        case .tokenRefreshFailed: return "Token refresh failed"
        case .notAuthenticated: return "Not authenticated with Google Drive"
        }
    }
}
