import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(
                                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        Text("Welcome to Todo")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 24) {
                        FeatureRow(symbol: "list.bullet.rectangle.portrait.fill", color: .blue,
                                   title: "Lists for Everything", detail: "Organize tasks into colorful lists, with Today, Scheduled and Flagged views.")
                        FeatureRow(symbol: "bell.badge.fill", color: .red,
                                   title: "Timely Reminders", detail: "Get notified when a task is due, on every device.")
                        FeatureRow(symbol: "icloud.fill", color: .cyan,
                                   title: "Synced with iCloud", detail: "Your tasks stay up to date on iPhone, iPad and Mac.")
                    }
                    .frame(maxWidth: 420)

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            auth.handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .frame(maxWidth: 380)
                        .id(colorScheme)  // the button doesn't restyle itself when the appearance changes

                        Button("Continue Without an Account") {
                            auth.continueWithoutAccount()
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 6)

                        if let error = auth.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)  // centered on iPad and Mac
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SignInView().environment(AuthManager())
}
