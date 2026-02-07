import AuthenticationServices
import CommonCrypto
import SwiftUI

@MainActor
@Observable
class AuthManager: NSObject {
    static let shared = AuthManager()

    var isAuthenticated = false
    var isLoading = false
    var isOfflineMode = false
    var user: APIClient.UserResponse?
    var error: String?

    // Retain the auth session to prevent deallocation during OAuth flow
    private var currentAuthSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        // Check if user previously chose offline mode
        isOfflineMode = UserDefaults.standard.bool(forKey: "offline_mode")
        if isOfflineMode {
            isAuthenticated = true
        }
        Task {
            await loadStoredAuth()
        }
    }

    private func loadStoredAuth() async {
        Log.auth.debug("Loading stored authentication...")
        await APIClient.shared.loadStoredTokens()
        
        if await APIClient.shared.isAuthenticated {
            Log.auth.debug("Found stored tokens, attempting to validate...")
            do {
                user = try await APIClient.shared.getCurrentUser()
                isAuthenticated = true
                let displayName = user?.displayName ?? "Unknown"
                Log.auth.info("Authentication validated successfully - User: \(displayName)")
            } catch APIError.unauthorized {
                Log.auth.info("Stored tokens are invalid - User needs to re-authenticate")
                await APIClient.shared.clearTokens()
                isAuthenticated = false
                user = nil
                // Don't set error here - this is normal flow for expired tokens
            } catch {
                Log.auth.error("Error validating stored auth: \(error)")
                // For other errors, keep tokens but show error
                self.error = "Unable to validate authentication: \(error.localizedDescription)"
            }
        } else {
            Log.auth.debug("No stored tokens found")
        }
    }

    func signInWithApple() {
        isLoading = true
        error = nil

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func continueWithoutAccount() {
        isOfflineMode = true
        isAuthenticated = true
        UserDefaults.standard.set(true, forKey: "offline_mode")
    }

    func signInWithGoogle() {
        isLoading = true
        error = nil

        Task {
            do {
                let idToken = try await performGoogleOAuthFlow()

                let response = try await APIClient.shared.authenticateWithGoogle(idToken: idToken)
                user = response.user
                isAuthenticated = true
                let displayName = user?.displayName ?? "Unknown"
                Log.auth.info("Google sign in successful - User: \(displayName)")
            } catch {
                if case GoogleSignInError.cancelled = error {
                    // User cancelled - don't show error
                    Log.auth.debug("Google sign in cancelled by user")
                } else {
                    Log.auth.error("Google sign in failed: \(error)")
                    self.error = "Google sign in failed: \(error.localizedDescription)"
                }
            }
            isLoading = false
        }
    }

    private func performGoogleOAuthFlow() async throws -> String {
        // Google OAuth configuration - uses iOS client ID for Sign In
        let clientId = GoogleSignInConfig.clientId
        let redirectUri = GoogleSignInConfig.redirectUri
        let scopes = GoogleSignInConfig.scopes.joined(separator: " ")

        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Build OAuth URL with PKCE
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw GoogleSignInError.invalidURL
        }

        // Get authorization code
        let authCode = try await getAuthorizationCode(from: authURL)

        // Exchange code for tokens using PKCE
        return try await exchangeCodeForIdToken(authCode: authCode, codeVerifier: codeVerifier)
    }

    private func getAuthorizationCode(from authURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: GoogleSignInConfig.callbackScheme
            ) { [weak self] callbackURL, error in
                // Clear the retained session
                Task { @MainActor in
                    self?.currentAuthSession = nil
                }

                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleSignInError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: GoogleSignInError.noIdToken)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            // Retain the session to prevent deallocation
            self.currentAuthSession = session

            if !session.start() {
                self.currentAuthSession = nil
                continuation.resume(throwing: GoogleSignInError.sessionFailed)
            }
        }
    }

    private func exchangeCodeForIdToken(authCode: String, codeVerifier: String) async throws -> String {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": GoogleSignInConfig.clientId,
            "code": authCode,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleSignInConfig.redirectUri
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleSignInError.tokenExchangeFailed(errorBody)
        }

        struct TokenResponse: Decodable {
            let id_token: String
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.id_token
    }

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func signOut() async {
        Log.auth.info("Signing out user")
        await APIClient.shared.clearTokens()
        isAuthenticated = false
        isOfflineMode = false
        user = nil
        error = nil
        UserDefaults.standard.removeObject(forKey: "offline_mode")
    }

    /// Manual refresh method - primarily for testing
    func refreshAuth() async throws {
        Log.auth.debug("Manual token refresh requested")
        _ = try await APIClient.shared.refreshAccessToken()
        user = try await APIClient.shared.getCurrentUser()
        Log.auth.debug("Manual refresh completed successfully")
    }
    
    /// Check if authentication is working without triggering refresh
    func validateAuthentication() async -> Bool {
        guard await APIClient.shared.isAuthenticated else {
            Log.auth.debug("No tokens available for validation")
            return false
        }
        
        do {
            user = try await APIClient.shared.getCurrentUser()
            Log.auth.debug("Authentication validation successful")
            return true
        } catch {
            Log.auth.error("Authentication validation failed: \(error)")
            return false
        }
    }
    
    /// Handle authentication errors from other parts of the app
    func handleAuthenticationError() {
        Log.auth.info("Authentication error reported - checking if re-auth needed")
        
        Task {
            let isValid = await validateAuthentication()
            if !isValid {
                Log.auth.error("Authentication is invalid - user needs to sign in again")
                await signOut()
                self.error = "Your session has expired. Please sign in again."
            }
        }
    }
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first
            else {
                return UIWindow()
            }
            return window
        }
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first
            else {
                return UIWindow()
            }
            return window
        }
    }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let authCodeData = credential.authorizationCode,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authCode = String(data: authCodeData, encoding: .utf8)
            else {
                self.error = "Failed to get Apple credentials"
                self.isLoading = false
                return
            }

            self.isLoading = true
            self.error = nil

            do {
                let response = try await APIClient.shared.authenticateWithApple(
                    identityToken: identityToken,
                    authorizationCode: authCode
                )
                self.user = response.user
                self.isAuthenticated = true
                let displayName = user?.displayName ?? "Unknown"
                Log.auth.info("Apple sign in successful - User: \(displayName)")
            } catch {
                Log.auth.error("Apple authentication failed: \(error)")
                self.error = "Authentication failed: \(error.localizedDescription)"
            }

            self.isLoading = false
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled
            {
                // User canceled - don't show error
                Log.auth.debug("Apple sign in cancelled by user")
                self.isLoading = false
                return
            }
            Log.auth.error("Apple authorization error: \(error)")
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
}

// MARK: - Google Sign In Configuration

enum GoogleSignInConfig {
    // iOS client ID (no secret required for mobile apps with implicit flow)
    static let clientId = "269334695221-sek2s7nqal8hmt2latimle4f8kgesg6l.apps.googleusercontent.com"
    // Google-provided URL scheme (reversed client ID)
    static let callbackScheme = "com.googleusercontent.apps.269334695221-sek2s7nqal8hmt2latimle4f8kgesg6l"
    static let redirectUri = "com.googleusercontent.apps.269334695221-sek2s7nqal8hmt2latimle4f8kgesg6l:/oauth2callback"
    static let scopes = [
        "openid",
        "email",
        "profile"
    ]
}

// MARK: - Google Sign In Errors

enum GoogleSignInError: LocalizedError {
    case cancelled
    case invalidURL
    case noIdToken
    case sessionFailed
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .invalidURL:
            return "Invalid authentication URL"
        case .noIdToken:
            return "Failed to get ID token"
        case .sessionFailed:
            return "Failed to start authentication session"
        case .tokenExchangeFailed(let details):
            return "Token exchange failed: \(details)"
        }
    }
}
