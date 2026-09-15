import Foundation
import CommonCrypto
import AppKit
import Network

@MainActor
public final class GoogleAuthService: ObservableObject {
    public static let shared = GoogleAuthService()

    @Published public var isSignedIn: Bool = false
    @Published public var userEmail: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil

    private let keychain = KeychainManager.shared
    private let keyAccessToken = "google_access_token"
    private let keyRefreshToken = "google_refresh_token"
    private let keyTokenExpiry = "google_token_expiry"
    private let keyClientId = "google_client_id"
    private let keyClientSecret = "google_client_secret"

    private var localListener: NWListener?

    private init() {
        checkSignInStatus()
    }

    public var clientId: String {
        get {
            keychain.get(key: keyClientId) ?? UserDefaults.standard.string(forKey: "custom_client_id") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = keychain.save(key: keyClientId, value: trimmed)
            UserDefaults.standard.set(trimmed, forKey: "custom_client_id")
        }
    }

    public var clientSecret: String {
        get {
            keychain.get(key: keyClientSecret) ?? UserDefaults.standard.string(forKey: "custom_client_secret") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = keychain.save(key: keyClientSecret, value: trimmed)
            UserDefaults.standard.set(trimmed, forKey: "custom_client_secret")
        }
    }

    public func checkSignInStatus() {
        if let token = keychain.get(key: keyAccessToken), !token.isEmpty {
            self.isSignedIn = true
        } else {
            self.isSignedIn = false
        }
    }

    public func signOut() {
        keychain.delete(key: keyAccessToken)
        keychain.delete(key: keyRefreshToken)
        keychain.delete(key: keyTokenExpiry)
        self.isSignedIn = false
        self.userEmail = nil
    }

    // MARK: - PKCE Helpers
    private func generateRandomString(length: Int = 64) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func sha256Base64Url(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func encodeFormParameters(_ params: [String: String]) -> Data? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let query = params.map { key, value in
            let encKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encVal = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encKey)=\(encVal)"
        }.joined(separator: "&")
        return query.data(using: .utf8)
    }

    // MARK: - OAuth Flow via Loopback Server
    public func startSignIn(customPort: UInt16 = 8765) async {
        let cleanId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else {
            self.errorMessage = "Please enter your Google OAuth Client ID first."
            return
        }

        self.isAuthenticating = true
        self.errorMessage = nil

        let codeVerifier = generateRandomString()
        let codeChallenge = sha256Base64Url(codeVerifier)
        let redirectUri = "http://127.0.0.1:\(customPort)/callback"

        // Cancel any lingering listener
        stopListener()

        do {
            let port = NWEndpoint.Port(rawValue: customPort)!
            let listener = try NWListener(using: .tcp, on: port)
            self.localListener = listener

            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
                    guard let self = self, let data = data, let request = String(data: data, encoding: .utf8) else { return }

                    if let code = Self.extractAuthCode(from: request) {
                        let html = """
                        <!DOCTYPE html>
                        <html>
                        <head><title>CalBar - Connected</title><meta charset="utf-8"></head>
                        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; text-align: center; padding-top: 60px; background: #f8f9fa;">
                            <div style="background: white; border-radius: 12px; padding: 32px; max-width: 400px; margin: 0 auto; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
                                <h2 style="color: #1a73e8; margin-top: 0;">Connected to CalBar!</h2>
                                <p style="color: #5f6368; font-size: 14px;">Google Calendar authorization was successful. You can close this tab and return to the menu bar.</p>
                            </div>
                        </body>
                        </html>
                        """
                        let response = "HTTP/1.1 200 OK\r\nContent-Length: \(html.utf8.count)\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(html)"
                        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
                            connection.cancel()
                        }))

                        Task { @MainActor in
                            self.stopListener()
                            await self.exchangeCodeForToken(code: code, codeVerifier: codeVerifier, redirectUri: redirectUri)
                        }
                    }
                }
            }

            listener.start(queue: .main)

            // Construct Google Authorization URL
            var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: cleanId),
                URLQueryItem(name: "redirect_uri", value: redirectUri),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/calendar.readonly email profile"),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent")
            ]

            if let authUrl = components.url {
                NSWorkspace.shared.open(authUrl)
            }
        } catch {
            self.isAuthenticating = false
            self.errorMessage = "Failed to start local login listener on port \(customPort): \(error.localizedDescription)"
        }
    }

    private func stopListener() {
        localListener?.cancel()
        localListener = nil
    }

    nonisolated private static func extractAuthCode(from requestString: String) -> String? {
        guard let firstLine = requestString.components(separatedBy: "\r\n").first else { return nil }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        let pathAndQuery = parts[1]
        guard let queryStart = pathAndQuery.firstIndex(of: "?") else { return nil }
        let queryString = String(pathAndQuery[pathAndQuery.index(after: queryStart)...])

        for param in queryString.components(separatedBy: "&") {
            let pair = param.components(separatedBy: "=")
            if pair.count == 2 && pair[0] == "code" {
                return pair[1].removingPercentEncoding ?? pair[1]
            }
        }
        return nil
    }

    // MARK: - Exchange Code for Tokens
    private func exchangeCodeForToken(code: String, codeVerifier: String, redirectUri: String) async {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let cleanId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var params: [String: String] = [
            "code": code,
            "client_id": cleanId,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        if !cleanSecret.isEmpty {
            params["client_secret"] = cleanSecret
        }
        request.httpBody = encodeFormParameters(params)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                var errorDescription = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 500)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let desc = json["error_description"] as? String {
                        errorDescription = desc
                    } else if let err = json["error"] as? String {
                        errorDescription = err
                    }
                } else if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                    errorDescription = raw
                }
                self.errorMessage = "Google OAuth failed: \(errorDescription)"
                self.isAuthenticating = false
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                _ = keychain.save(key: keyAccessToken, value: accessToken)
                if let refreshToken = json["refresh_token"] as? String {
                    _ = keychain.save(key: keyRefreshToken, value: refreshToken)
                }
                if let expiresIn = json["expires_in"] as? Double {
                    let expiryDate = Date().addingTimeInterval(expiresIn)
                    _ = keychain.save(key: keyTokenExpiry, value: String(expiryDate.timeIntervalSince1970))
                }

                self.isSignedIn = true
                self.isAuthenticating = false
                self.errorMessage = nil
            }
        } catch {
            self.errorMessage = "Network error: \(error.localizedDescription)"
            self.isAuthenticating = false
        }
    }

    // MARK: - Valid Token Retrieval with Auto-Refresh
    public func getValidAccessToken() async -> String? {
        guard let accessToken = keychain.get(key: keyAccessToken) else { return nil }

        if let expiryStr = keychain.get(key: keyTokenExpiry),
           let expiryInterval = Double(expiryStr) {
            let expiryDate = Date(timeIntervalSince1970: expiryInterval)
            if expiryDate.timeIntervalSinceNow < 60 {
                return await refreshAccessToken()
            }
        }

        return accessToken
    }

    private func refreshAccessToken() async -> String? {
        guard let refreshToken = keychain.get(key: keyRefreshToken),
              let url = URL(string: "https://oauth2.googleapis.com/token") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let cleanId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var params: [String: String] = [
            "client_id": cleanId,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        if !cleanSecret.isEmpty {
            params["client_secret"] = cleanSecret
        }
        request.httpBody = encodeFormParameters(params)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newAccessToken = json["access_token"] as? String {
                _ = keychain.save(key: keyAccessToken, value: newAccessToken)
                if let expiresIn = json["expires_in"] as? Double {
                    let expiryDate = Date().addingTimeInterval(expiresIn)
                    _ = keychain.save(key: keyTokenExpiry, value: String(expiryDate.timeIntervalSince1970))
                }
                return newAccessToken
            }
        } catch {
            return nil
        }
        return nil
    }
}
