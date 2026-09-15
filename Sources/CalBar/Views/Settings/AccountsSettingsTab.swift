import SwiftUI

public struct AccountsSettingsTab: View {
    @ObservedObject var authService = GoogleAuthService.shared
    @ObservedObject var coordinator: CalendarSyncCoordinator
    @ObservedObject var eventKitService = EventKitService.shared

    @State private var clientIdInput: String = ""
    @State private var clientSecretInput: String = ""
    @State private var showSetupInstructions: Bool = true

    public init(coordinator: CalendarSyncCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Section 1: Sync Provider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync Provider")
                        .font(.system(size: 13, weight: .bold))

                    Picker("", selection: $coordinator.syncProvider) {
                        ForEach(SyncProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)

                // Section 2: Account Details
                if coordinator.syncProvider == .googleDirect {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Google Calendar (OAuth 2.0)")
                            .font(.system(size: 13, weight: .bold))

                        if authService.isSignedIn {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(GooglePalette.googleGreen)
                                    .font(.system(size: 16))
                                Text("Connected to Google Calendar")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Button("Sign Out") {
                                    authService.signOut()
                                    Task { await coordinator.refreshAll() }
                                }
                            }
                            .padding(10)
                            .background(GooglePalette.googleGreen.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                // Client ID Field
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Google Client ID")
                                        .font(.system(size: 11.5, weight: .semibold))

                                    TextField("Paste your Google Client ID here", text: $clientIdInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12))
                                }

                                // Client Secret Field
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Google Client Secret")
                                            .font(.system(size: 11.5, weight: .semibold))
                                        Text("(Required for Web application; optional for Desktop app)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }

                                    SecureField("Paste your Client Secret here", text: $clientSecretInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 12))
                                }

                                // Buttons
                                HStack {
                                    Button("Save Credentials") {
                                        authService.clientId = clientIdInput
                                        authService.clientSecret = clientSecretInput
                                    }
                                    .disabled(clientIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    Spacer()

                                    Button(action: {
                                        authService.clientId = clientIdInput
                                        authService.clientSecret = clientSecretInput
                                        Task {
                                            await authService.startSignIn()
                                            if authService.isSignedIn {
                                                await coordinator.refreshAll()
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            if authService.isAuthenticating {
                                                ProgressView().scaleEffect(0.65)
                                            }
                                            Text("Sign in with Google")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(clientIdInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || authService.isAuthenticating)
                                }
                                .padding(.top, 4)

                                // Error display
                                if let error = authService.errorMessage {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(error)
                                                .font(.system(size: 11.5, weight: .medium))
                                                .foregroundColor(.red)

                                            if error.contains("client_secret") {
                                                Text("Tip: In Google Cloud Console, your Client ID has a corresponding Client Secret. Paste it above and click Sign in again.")
                                                    .font(.system(size: 10.5))
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 2)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                                }

                                // Setup Guide
                                DisclosureGroup("Google Cloud Setup Instructions", isExpanded: $showSetupInstructions) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("1. Visit **console.cloud.google.com** and open your project.")
                                        Text("2. Enable the **Google Calendar API** under APIs & Services > Library.")
                                        Text("3. In **OAuth consent screen**, ensure your email is added under **Test users**.")
                                        Text("4. In **Credentials**, view your OAuth 2.0 Client ID:")
                                        Text("   • If created as **Web application**: Copy both the **Client ID** and the **Client Secret** into the fields above.")
                                        Text("   • If created as **Desktop app**: No client secret is required.")
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)

                } else if coordinator.syncProvider == .eventKit {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("macOS Calendar Sync (EventKit)")
                            .font(.system(size: 13, weight: .bold))

                        HStack {
                            Image(systemName: eventKitService.hasAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(eventKitService.hasAccess ? GooglePalette.googleGreen : .orange)
                            Text(eventKitService.hasAccess ? "macOS Calendar Access Granted" : statusTitle)
                                .font(.system(size: 13, weight: .medium))

                            Spacer()

                            if eventKitService.hasAccess {
                                Button("Refresh") {
                                    Task { await coordinator.refreshAll() }
                                }
                            }
                        }

                        if !eventKitService.isRunningInAppBundle {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("CalBar is running as a CLI process. macOS requires running the signed **CalBar.app** to show the Calendar permission prompt.")
                                        .font(.system(size: 11))
                                }

                                Button("Launch CalBar.app") {
                                    let task = Process()
                                    task.launchPath = "/usr/bin/open"
                                    task.arguments = ["CalBar.app"]
                                    try? task.run()
                                    NSApp.terminate(nil)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        } else if !eventKitService.hasAccess {
                            if eventKitService.authorizationStatus == .denied || eventKitService.authorizationStatus == .restricted {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Calendar access is currently disabled for CalBar in macOS System Settings.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)

                                    HStack {
                                        Button("Open Privacy & Security Settings") {
                                            eventKitService.openPrivacySettings()
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button("Re-check Access") {
                                            eventKitService.checkAuthorization()
                                            if eventKitService.hasAccess {
                                                Task { await coordinator.refreshAll() }
                                            }
                                        }
                                    }
                                }
                            } else {
                                Button("Grant Access") {
                                    Task {
                                        _ = await eventKitService.requestAccess()
                                        await coordinator.refreshAll()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        Text("Tip: When you add your Google account in macOS System Settings > Internet Accounts, all your Google calendars sync here automatically with zero configuration!")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)

                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Demo Mode")
                            .font(.system(size: 13, weight: .bold))

                        Text("Currently using interactive sample data with realistic meetings and Google Meet links.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
        .onAppear {
            clientIdInput = authService.clientId
            clientSecretInput = authService.clientSecret
            eventKitService.checkAuthorization()
        }
    }

    private var statusTitle: String {
        switch eventKitService.authorizationStatus {
        case .denied:
            return "Permission Denied by macOS"
        case .restricted:
            return "Permission Restricted"
        case .notDetermined:
            return "Permission Needed"
        default:
            return "Permission Needed"
        }
    }
}
