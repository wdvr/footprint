import AuthenticationServices
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
        await APIClient.shared.loadStoredTokens()
        if await APIClient.shared.isAuthenticated {
            do {
                user = try await APIClient.shared.getCurrentUser()
                isAuthenticated = true
            } catch {
                // Token expired or invalid
                await APIClient.shared.clearTokens()
            }
        }
    }

    func signInWithApple() {
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
            } catch {
                if case GoogleSignInError.cancelled = error {
                    // User cancelled - don't show error
                } else {
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

        // Build OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "id_token"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "nonce", value: UUID().uuidString)
        ]

        guard let authURL = components.url else {
            throw GoogleSignInError.invalidURL
        }

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
                      let fragment = callbackURL.fragment,
                      let idToken = fragment.components(separatedBy: "&")
                          .first(where: { $0.hasPrefix("id_token=") })?
                          .replacingOccurrences(of: "id_token=", with: "")
                else {
                    continuation.resume(throwing: GoogleSignInError.noIdToken)
                    return
                }

                continuation.resume(returning: idToken)
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

    func signOut() async {
        await APIClient.shared.clearTokens()
        isAuthenticated = false
        isOfflineMode = false
        user = nil
        UserDefaults.standard.removeObject(forKey: "offline_mode")
    }

    func refreshAuth() async throws {
        _ = try await APIClient.shared.refreshAccessToken()
        user = try await APIClient.shared.getCurrentUser()
    }
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
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
            } catch {
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
                return
            }
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Google Sign In Configuration

enum GoogleSignInConfig {
    // iOS client ID (no secret required for mobile apps with implicit flow)
    static let clientId = "269334695221-0h0nbiimdobmjefsi13dhvgpsidhk5hf.apps.googleusercontent.com"
    static let callbackScheme = "com.wouterdevriendt.footprint"
    static let redirectUri = "com.wouterdevriendt.footprint:/oauth2callback"
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
        }
    }
}
