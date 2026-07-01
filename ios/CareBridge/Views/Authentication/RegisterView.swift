import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var selectedRole = "patient"
    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let roles: [(String, String)] = [
        ("patient", "Patient"),
        ("family", "Family"),
        ("caregiver", "Caregiver")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Type") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.0) { role in
                            Text(role.1).tag(role.0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Personal Information") {
                    TextField("First Name", text: $firstName)
                        .textInputAutocapitalization(.words)
                    TextField("Last Name", text: $lastName)
                        .textInputAutocapitalization(.words)
                    TextField(selectedRole == "family" ? "Phone (Emergency Contact)" : "Phone (Optional)", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Account Details") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                }

                if selectedRole == "family" {
                    Section {
                        TextField("Patient Join Code", text: $joinCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Link to Patient")
                    } footer: {
                        Text("Ask the patient's care team for their join code to view their health data.")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await register() }
                    } label: {
                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else {
                            Text("Create Account").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !firstName.isEmpty && !lastName.isEmpty &&
        password == confirmPassword && password.count >= 6 &&
        (selectedRole != "family" || !phone.isEmpty)
    }

    private func register() async {
        guard password == confirmPassword else { errorMessage = "Passwords do not match"; return }
        guard password.count >= 6 else { errorMessage = "Password must be at least 6 characters"; return }
        if selectedRole == "family" && phone.isEmpty { errorMessage = "Phone number is required for family accounts"; return }

        isLoading = true
        errorMessage = nil
        do {
            try await authManager.register(
                email: email, password: password,
                firstName: firstName, lastName: lastName,
                role: selectedRole,
                phone: phone.isEmpty ? nil : phone,
                joinCode: joinCode.isEmpty ? nil : joinCode
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthenticationManager())
}
