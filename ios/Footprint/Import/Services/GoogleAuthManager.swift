import AuthenticationServices
import Foundation
import UIKit

@MainActor
@Observable
class GoogleAuthManager: NSObject {
    static let shared = GoogleAuthManager()

    var isConnected = false
    var isLoading = false
    var connectedEmail: String?
    var error: String?

    // Retain the auth session to prevent deallocation during OAuth flow
    private var currentAuthSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
        Task {
            await checkConnectionStatus()
        }
    }

    /// Check if Google account is connected via backend
    func checkConnectionStatus() async {
        guard await APIClient.shared.isAuthenticated else { return }

        do {
            let status: GoogleConnectionStatus = try await APIClient.shared.request(
                path: "/import/google/status",
                method: .get
            )
            isConnected = status.isConnected
            connectedEmail = status.email
        } catch {
            // Not connected or error - treat as not connected
            isConnected = false
            connectedEmail = nil
        }
    }

    /// Present Google Sign-In and exchange auth code with backend
    func signIn(presentingViewController: Any? = nil) async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Use AuthenticationServices for OAuth flow
        let authCode = try await performOAuthFlow()

        print("[GoogleAuth] Got auth code, checking if authenticated...")
        let isAuth = await APIClient.shared.isAuthenticated
        print("[GoogleAuth] APIClient.isAuthenticated = \(isAuth)")

        // Exchange auth code with backend
        print("[GoogleAuth] Calling /import/google/connect...")
        do {
            let response: GoogleConnectResponse = try await APIClient.shared.request(
                path: "/import/google/connect",
                method: .post,
                body: GoogleConnectRequest(authorizationCode: authCode)
            )
            print("[GoogleAuth] Connect succeeded: \(response.email)")
            isConnected = true
            connectedEmail = response.email
        } catch {
            print("[GoogleAuth] Connect FAILED: \(error)")
            throw error
        }
    }

    /// Disconnect Google account
    func disconnect() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let _: EmptyImportResponse = try await APIClient.shared.request(
                path: "/import/google/disconnect",
                method: .delete
            )
            isConnected = false
            connectedEmail = nil
        } catch {
            self.error = "Failed to disconnect: \(error.localizedDescription)"
        }
    }

    /// Perform OAuth flow using ASWebAuthenticationSession
    private func performOAuthFlow() async throws -> String {
        // Google OAuth configuration
        let clientId = GoogleOAuthConfig.clientId
        let redirectUri = GoogleOAuthConfig.redirectUri
        let scopes = GoogleOAuthConfig.scopes.joined(separator: " ")

        // Build URL with proper encoding
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw GoogleAuthError.connectionFailed("Invalid auth URL")
        }

        print("[GoogleAuth] Starting OAuth flow with URL: \(authURL)")
        print("[GoogleAuth] Callback scheme: \(GoogleOAuthConfig.callbackScheme)")

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: GoogleOAuthConfig.callbackScheme
            ) { [weak self] callbackURL, error in
                print("[GoogleAuth] Callback received - URL: \(String(describing: callbackURL)), Error: \(String(describing: error))")

                // Clear the retained session
                Task { @MainActor in
                    self?.currentAuthSession = nil
                }

                if let error = error {
                    let nsError = error as NSError
                    print("[GoogleAuth] Error code: \(nsError.code), domain: \(nsError.domain)")
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    print("[GoogleAuth] No auth code in callback URL")
                    continuation.resume(throwing: GoogleAuthError.noAuthCode)
                    return
                }

                print("[GoogleAuth] Successfully got auth code")
                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            // Retain the session to prevent deallocation
            self.currentAuthSession = session

            let started = session.start()
            print("[GoogleAuth] Session started: \(started)")

            if !started {
                self.currentAuthSession = nil
                continuation.resume(throwing: GoogleAuthError.connectionFailed("Failed to start authentication session"))
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Check if already on main thread to avoid deadlock
        if Thread.isMainThread {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first
            else {
                return ASPresentationAnchor()
            }
            return window
        } else {
            return DispatchQueue.main.sync {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.windows.first
                else {
                    return ASPresentationAnchor()
                }
                return window
            }
        }
    }
}

// MARK: - Errors

enum GoogleAuthError: LocalizedError {
    case cancelled
    case noAuthCode
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .noAuthCode:
            return "Failed to get authorization code"
        case .connectionFailed(let message):
            return message
        }
    }
}

// MARK: - OAuth Configuration

enum GoogleOAuthConfig {
    // Web app client ID (has secret for code exchange)
    static let clientId = "269334695221-0h0nbiimdobmjefsi13dhvgpsidhk5hf.apps.googleusercontent.com"
    static let callbackScheme = "com.wd.footprint.app"
    // HTTPS redirect goes to our backend, which redirects to the app scheme
    static let redirectUri = "https://footprintmaps.com/api/import/google/oauth/callback"
    static let scopes = [
        "openid",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/calendar.readonly"
    ]
}

// MARK: - API Models

struct GoogleConnectRequest: Encodable {
    let authorizationCode: String
}

struct GoogleConnectResponse: Decodable {
    let email: String
    let connected: Bool
}

struct GoogleConnectionStatus: Decodable {
    let isConnected: Bool
    let email: String?
}

struct EmptyImportResponse: Decodable {}
