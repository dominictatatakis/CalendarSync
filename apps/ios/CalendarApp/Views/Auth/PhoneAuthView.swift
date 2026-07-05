import SwiftUI
import AuthenticationServices

struct PhoneAuthView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var navigateToOTP = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Branding
                VStack(spacing: 10) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.tint)
                    Text("CalendarSync")
                        .font(.largeTitle.bold())
                    Text("Plan together, effortlessly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer().frame(height: 40)

                VStack(spacing: 12) {
                    // Email field
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Continue button
                    Button(action: sendOTP) {
                        Group {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Continue with Email")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .disabled(!isValidEmail || auth.isLoading)
                }
                .padding(.horizontal)

                // Divider
                HStack {
                    Rectangle().fill(.separator).frame(height: 1)
                    Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                    Rectangle().fill(.separator).frame(height: 1)
                }
                .padding(.horizontal)
                .padding(.vertical, 20)

                // Social sign-in
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        auth.prepareAppleSignInRequest(request)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task { await auth.signInWithApple(authorization: authorization) }
                        case .failure(let error):
                            auth.errorMessage = error.localizedDescription
                        }
                    }
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Button(action: signInWithGoogle) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Sign in with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }

                Spacer()

                #if DEBUG
                Button("Skip login (dev mode)") {
                    auth.signInAsGuest()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
                #endif
            }
            .navigationDestination(isPresented: $navigateToOTP) {
                OTPVerificationView(email: email)
                    .environmentObject(auth)
            }
        }
    }

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    private func sendOTP() {
        Task {
            do {
                try await auth.sendOTP(email: email)
                navigateToOTP = true
            } catch {
                auth.errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        Task { await auth.signInWithGoogle(presenting: root) }
    }
}
