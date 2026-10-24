import SwiftUI

// ─── CareBridge Color Palette ─────────────────────────────────────────────────
extension Color {
    static let cbPrimary     = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let cbPrimaryDark = Color(red: 29/255,  green: 78/255,  blue: 216/255)
    static let cbGreen       = Color(red: 16/255,  green: 185/255, blue: 129/255)
    static let cbAmber       = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let cbRed         = Color(red: 239/255, green: 68/255,  blue: 68/255)
    static let cbTeal        = Color(red: 20/255,  green: 184/255, blue: 166/255)
    static let cbBackground  = Color(red: 248/255, green: 250/255, blue: 252/255)
    static let cbBorder      = Color(red: 226/255, green: 232/255, blue: 240/255)
}

// MARK: - HIPAA Consent View

struct HIPAAConsentView: View {
    let onAccept: () -> Void
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.cbPrimary)
                        Text("HIPAA Privacy Notice")
                            .font(.title2).fontWeight(.bold)
                        Text("Please review CareBridge's privacy practices before continuing.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 20) {
                        hipaaSection(
                            icon: "person.badge.shield.checkmark",
                            title: "Your Privacy Rights",
                            text: "CareBridge handles Protected Health Information (PHI) in accordance with HIPAA. Your health data is accessed only by your authorized care team and family members you have approved."
                        )
                        hipaaSection(
                            icon: "waveform.path.ecg",
                            title: "How We Use Your Information",
                            text: "We collect wellness check-ins, medications, appointments, and care notes to coordinate your care. This data is shared only within your care network and is never sold to third parties."
                        )
                        hipaaSection(
                            icon: "cpu",
                            title: "AI Features Disclosure",
                            text: "CareBridge uses AI to generate health summaries and a care companion chatbot. AI responses are not medical advice and do not replace your healthcare provider. Always consult a professional for medical decisions."
                        )
                        hipaaSection(
                            icon: "lock.fill",
                            title: "Data Security",
                            text: "Your health information is encrypted with AES-256 when stored and travels only over encrypted connections. Your sign-in is kept in the iPhone's secure Keychain. Access is controlled by authenticated logins and role-based permissions in compliance with HIPAA Security Rule requirements."
                        )
                        hipaaSection(
                            icon: "hand.raised.fill",
                            title: "Your Rights",
                            text: "You have the right to access, correct, or request deletion of your health records. Contact your healthcare provider to exercise these rights at any time."
                        )
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        Button(action: onAccept) {
                            Text("I Understand and Agree")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.cbPrimary)
                                .cornerRadius(12)
                        }
                        Button(action: { authManager.logout() }) {
                            Text("Decline and Sign Out")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private func hipaaSection(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.cbPrimary)
                .frame(width: 28)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - App Entry

@main
struct CareBridgeApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var accessibility = AccessibilityManager.shared
    @AppStorage("hipaa_accepted") private var hipaaAccepted = false

    init() {
        // Install crash diagnostics first, before anything else can fail, so any
        // abort during launch is still captured with its reason + stack trace.
        CrashReporter.install()

        let bgUIColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        UITableView.appearance().backgroundColor = bgUIColor
        UICollectionView.appearance().backgroundColor = bgUIColor
        UITabBar.appearance().backgroundColor = bgUIColor
        UITabBar.appearance().isTranslucent = true
        NotificationsManager.shared.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    if hipaaAccepted {
                        MainTabView()
                            .environmentObject(authManager)
                            .environmentObject(accessibility)
                            .preferredColorScheme(.light)
                            .accessibleRoot()
                            .onAppear { LiveNotificationsManager.shared.connect(authManager: authManager) }
                            .onChange(of: authManager.isAuthenticated) { _, isAuthed in
                                if !isAuthed { LiveNotificationsManager.shared.disconnect() }
                            }
                    } else {
                        HIPAAConsentView(onAccept: { hipaaAccepted = true })
                            .environmentObject(authManager)
                            .environmentObject(accessibility)
                            .preferredColorScheme(.light)
                            .accessibleRoot()
                    }
                } else {
                    LoginView()
                        .environmentObject(authManager)
                        .environmentObject(accessibility)
                        .preferredColorScheme(.light)
                        .accessibleRoot()
                }
            }
        }
    }
}
