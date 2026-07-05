import SwiftUI

struct OTPVerificationView: View {
    let email: String
    @EnvironmentObject var auth: AuthViewModel
    @State private var otp = ""
    @State private var resendCountdown = 30
    @State private var canResend = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Check your email")
                    .font(.title2.bold())
                Text("We sent a 6-digit code to\n\(email)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                TextField("6-digit code", text: $otp)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: otp) { _, new in
                        otp = String(new.filter(\.isNumber).prefix(6))
                        if otp.count == 6 { verify() }
                    }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button(action: verify) {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(otp.count != 6 || auth.isLoading)

                Button(canResend ? "Resend code" : "Resend in \(resendCountdown)s") {
                    resend()
                }
                .font(.subheadline)
                .foregroundStyle(canResend ? Color.accentColor : Color.secondary)
                .disabled(!canResend)
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startCountdown() }
    }

    private func verify() {
        Task {
            do {
                try await auth.verifyOTP(email: email, token: otp)
            } catch {
                auth.errorMessage = error.localizedDescription
                otp = ""
            }
        }
    }

    private func resend() {
        Task {
            do {
                try await auth.sendOTP(email: email)
                canResend = false
                resendCountdown = 30
                startCountdown()
            } catch {
                auth.errorMessage = error.localizedDescription
            }
        }
    }

    private func startCountdown() {
        Task {
            for i in stride(from: 30, through: 1, by: -1) {
                resendCountdown = i
                try? await Task.sleep(for: .seconds(1))
            }
            canResend = true
        }
    }
}
