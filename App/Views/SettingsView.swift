import AuthenticationServices
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmingSignOut = false

    var body: some View {
        Form {
            Section("Account") {
                switch auth.mode {
                case .apple:
                    LabeledContent("Signed in with Apple") {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    if let name = auth.displayName { LabeledContent("Name", value: name) }
                    if let email = auth.email { LabeledContent("Email", value: email) }
                    Button("Sign Out", role: .destructive) { confirmingSignOut = true }
                case .guest, .signedOut:
                    Text("Sign in to personalize Todo. Your tasks sync with iCloud either way.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        auth.handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 44)
                    .id(colorScheme)
                    if let error = auth.lastError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
            }

            Section {
                LabeledContent("iCloud Sync", value: isICloudAvailable ? "On" : "Not Signed In to iCloud")
            } footer: {
                Text("Tasks are stored in your private iCloud database and appear on every device signed in to the same Apple Account.")
            }

            Section("Notifications") {
                LabeledContent("Reminders", value: notificationStatusText)
                if notificationStatus == .notDetermined {
                    Button("Allow Notifications") {
                        Task {
                            await ReminderScheduler.shared.requestAuthorizationIfNeeded()
                            await loadNotificationStatus()
                        }
                    }
                } else if notificationStatus == .denied {
                    Button("Open System Settings", action: openNotificationSettings)
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        #else
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        #endif
        .confirmationDialog("Sign out of Todo?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                dismiss()
                auth.signOut()
            }
        } message: {
            Text("Your tasks stay in iCloud.")
        }
        .task { await loadNotificationStatus() }
    }

    private var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Turned Off"
        default: "Not Set Up"
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func loadNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func openNotificationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { openURL(url) }
        #endif
    }
}
