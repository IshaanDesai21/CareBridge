
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingRegister = false
    @State private var showServerConfig = false
    @State private var serverURLInput = UserDefaults.standard.string(forKey: APIService.serverURLKey) ?? APIService.defaultServerURL
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.cbBackground.ignoresSafeArea()

                ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 20)
                    
                    // Logo and title
                    VStack(spacing: 16) {
                        if let uiImage = UIImage(named: "Logo"), uiImage.size.width > 0 {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: Color.cbPrimary.opacity(0.2), radius: 12, x: 0, y: 4)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.cbPrimary.opacity(0.1))
                                    .frame(width: 88, height: 88)
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(Color.cbPrimary)
                            }
                        }
                        
                        Text("CareBridge")
                            .font(.system(size: 42, weight: .bold, design: .serif))
                        
                        Text("Healthcare Coordination")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Demo logins
                    VStack(spacing: 12) {
                        Text("Quick Testing Login")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.cbPrimary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 8) {
                            ForEach([("patient", "Patient"), ("caregiver", "Caregiver"), ("family", "Family")], id: \.0) { role, label in
                                Button(action: {
                                    Task { await demoLogin(role: role) }
                                }) {
                                    Text(label)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.cbPrimary.opacity(0.08))
                                        .foregroundStyle(Color.cbPrimary)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cbPrimary.opacity(0.25), lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Login form
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cbBorder, lineWidth: 1.5)
                            )

                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cbBorder, lineWidth: 1.5)
                            )
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Button {
                            Task {
                                await login()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Sign In")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(Color.cbPrimary)
                        .cornerRadius(12)
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        
                        Button {
                            showingRegister = true
                        } label: {
                            Text("Don't have an account? **Sign Up**")
                                .font(.subheadline)
                        }

                        HStack {
                            Rectangle().fill(Color.cbBorder).frame(height: 1)
                            Text("or").font(.caption).foregroundStyle(.secondary)
                            Rectangle().fill(Color.cbBorder).frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .cornerRadius(12)
                        .disabled(isLoading)
                    }

                    // Server config
                    Button(action: { withAnimation { showServerConfig.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "network")
                                .font(.system(size: 11))
                            Text(showServerConfig ? "Hide Server Settings" : "Server Settings")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.cbBorder)
                    }

                    if showServerConfig {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Backend Server URL")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            TextField("http://192.168.1.x:3000", text: $serverURLInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cbBorder, lineWidth: 1.5))
                                .onChange(of: serverURLInput) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: APIService.serverURLKey)
                                }
                            Text("On device, enter your Mac's local IP instead of localhost.\nFind it: System Settings → Network → Wi-Fi → Details → IP Address\nExample: http://192.168.1.42:3000")
                                .font(.caption2)
                                .foregroundStyle(Color(red: 0.5, green: 0.55, blue: 0.62))
                                .lineSpacing(3)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 32)
                } // ScrollView
            }
            .sheet(isPresented: $showingRegister) {
                RegisterView()
                    .environmentObject(authManager)
            }
        }
    }
    
    @MainActor
    private func login() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    private func demoLogin(role: String) async {
        isLoading = true
        errorMessage = nil
        authManager.loginAsDemo(role: role)
        isLoading = false
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple sign-in failed"
                return
            }
            isLoading = true
            errorMessage = nil
            Task { @MainActor in
                do {
                    // Apple only shares the name on the first authorization —
                    // forward it so the backend can store it at account creation.
                    try await authManager.loginWithApple(
                        identityToken: identityToken,
                        firstName: credential.fullName?.givenName,
                        lastName: credential.fullName?.familyName,
                        role: "patient"
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        case .failure(let error):
            // Tapping outside the sheet cancels — not worth surfacing as an error.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
