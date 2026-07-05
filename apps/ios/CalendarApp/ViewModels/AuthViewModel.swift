import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseService()
    private var pendingAppleNonce: String?

    init() {
        Task { await checkSession() }
    }

    func checkSession() async {
        if let user = await service.currentUser() {
            currentUser = user
            isAuthenticated = true
        }
    }

    func sendOTP(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        try await service.sendOTP(email: email)
    }

    func verifyOTP(email: String, token: String) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        let user = try await service.verifyOTP(email: email, token: token)
        currentUser = user
        isAuthenticated = true
    }

    // MARK: - Sign in with Apple

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        pendingAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = pendingAppleNonce else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let user = try await service.signInWithAppleToken(idToken: idToken, nonce: nonce)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in with Google

    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let config = GIDConfiguration(clientID: Secrets.googleClientID)
            GIDSignIn.sharedInstance.configuration = config
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController, hint: nil, additionalScopes: [])
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in failed: missing ID token"
                return
            }
            let accessToken = result.user.accessToken.tokenString
            let user = try await service.signInWithGoogleToken(idToken: idToken, accessToken: accessToken)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    func signOut() async {
        try? await service.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func updateDisplayName(_ name: String) async throws {
        guard let uid = currentUser?.id else { return }
        try await service.updateDisplayName(name, userID: uid)
        currentUser?.displayName = name
    }

    #if DEBUG
    func signInAsGuest() {
        currentUser = AppUser(id: "dev-user", email: "dev@example.com", displayName: "Dev User")
        isAuthenticated = true
    }
    #endif
}
