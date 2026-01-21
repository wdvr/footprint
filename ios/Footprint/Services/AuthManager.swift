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
