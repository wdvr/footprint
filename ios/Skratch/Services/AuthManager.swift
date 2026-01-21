import AuthenticationServices
import SwiftUI

@MainActor
@Observable
class AuthManager: NSObject {
    static let shared = AuthManager()

    var isAuthenticated = false
    var isLoading = false
    var user: APIClient.UserResponse?
    var error: String?

    private override init() {
        super.init()
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
        controller.performRequests()
    }

    func signOut() async {
        await APIClient.shared.clearTokens()
        isAuthenticated = false
        user = nil
    }

    func refreshAuth() async throws {
        _ = try await APIClient.shared.refreshAccessToken()
        user = try await APIClient.shared.getCurrentUser()
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
