import SwiftUI
import UserNotifications

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var details: PhysicalDetails?
    @State private var patientId: Int?
    @State private var isLoading = true
    @State private var showEditPhysical = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.cbPrimary, Color.cbTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 70, height: 70)
                            Text(initials)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.fullName ?? "User")
                                .font(.title3).fontWeight(.bold)
                            Text(authManager.currentUser?.email ?? "")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let gender = details?.gender {
                                Text(gender.capitalized)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Health Information — only meaningful for the patient's own profile.
                // Caregivers view a patient's physical details from that patient's
                // record (PatientDetailCaregiverView), not from their own profile.
                if isPatientRole {
                    Section("Health Information") {
                        if let pid = patientId {
                            Button {
                                showEditPhysical = true
                            } label: {
                                HStack {
                                    Label("Physical Details", systemImage: "scalemass.fill")
                                    Spacer()
                                    if let h = details?.heightCm {
                                        Text(String(format: "%.0f cm", h))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                            .sheet(isPresented: $showEditPhysical, onDismiss: { Task { await loadDetails() } }) {
                                EditPhysicalDetailsView(patientId: pid, existing: details)
                                    .environmentObject(authManager)
                            }
                        }
                        NavigationLink(destination: MedicalHistoryView(details: details)) {
                            Label("Medical History", systemImage: "doc.text.fill")
                        }
                        NavigationLink(destination: EmergencyContactsView(contacts: details?.emergencyContacts ?? [])) {
                            Label("Emergency Contacts", systemImage: "phone.fill")
                        }
                        NavigationLink(destination: CareTeamView(members: details?.careTeam ?? [])) {
                            Label("Care Team", systemImage: "person.2.fill")
                        }
                    }
                }

                // Settings
                Section("Settings") {
                    NavigationLink(destination: AccessibilitySettingsView()) {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                    NavigationLink(destination: NotificationsSettingsView()) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    NavigationLink(destination: ServerSettingsView()) {
                        Label("Server Connection", systemImage: "network")
                    }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }

                // Account deletion — required in-app by App Store Guideline 5.1.1(v).
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        if isDeletingAccount {
                            HStack {
                                ProgressView()
                                Text("Deleting Account…")
                            }
                        } else {
                            Label("Delete Account", systemImage: "trash")
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("Permanently deletes your account and all associated data, including check-ins, medications, notes, and chat history. This cannot be undone.")
                }
            }
            .navigationTitle("Profile")
            .task { await loadDetails() }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your account and all health data from CareBridge. This action cannot be undone.")
            }
            .alert("Couldn't Delete Account", isPresented: .init(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private var isPatientRole: Bool {
        authManager.currentUser?.role == "patient" || authManager.currentUser?.role == nil
    }

    private var initials: String {
        let f = authManager.currentUser?.firstName?.first.map(String.init) ?? ""
        let l = authManager.currentUser?.lastName?.first.map(String.init) ?? ""
        return f + l
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await authManager.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeletingAccount = false
    }

    private func loadDetails() async {
        // Caregivers, family, and organization accounts don't have a patient
        // record of their own — nothing to load for them.
        guard isPatientRole, let token = authManager.token else { isLoading = false; return }
        do {
            let pid = try await APIService.shared.getMyPatient(token: token)
            patientId = pid
            details = try await APIService.shared.getPatientDetails(patientId: pid, token: token)
        } catch {
            print("Profile details load error: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Medical History

struct MedicalHistoryView: View {
    let details: PhysicalDetails?

    var body: some View {
        List {
            if let history = details?.medicalHistory, !history.isEmpty {
                Section("Medical History") {
                    Text(history)
                        .font(.body)
                        .padding(.vertical, 4)
                }
            }

            if let diagnoses = details?.diagnoses, !diagnoses.isEmpty {
                Section("Diagnoses") {
                    ForEach(diagnoses, id: \.self) { d in
                        Label(d, systemImage: "cross.case.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }

            if let allergies = details?.allergies, !allergies.isEmpty {
                Section("Allergies") {
                    ForEach(allergies, id: \.self) { a in
                        Label(a, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            if details == nil {
                Section {
                    Text("No medical history on file.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Medical History")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Emergency Contacts

struct EmergencyContactsView: View {
    let contacts: [EmergencyContact]

    var body: some View {
        List {
            if contacts.isEmpty {
                Section {
                    Text("No emergency contacts on file.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(contacts) { contact in
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(contact.isPrimary == true ? Color.cbPrimary.opacity(0.15) : Color.secondary.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.fill")
                                    .foregroundStyle(contact.isPrimary == true ? Color.cbPrimary : .secondary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(contact.name)
                                        .font(.headline)
                                    if contact.isPrimary == true {
                                        Text("PRIMARY")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.cbPrimary.opacity(0.15))
                                            .foregroundStyle(Color.cbPrimary)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(contact.relation)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                if let url = URL(string: "tel:\(contact.phone.filter { $0.isNumber })") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "phone.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.cbGreen)
                            }
                        }
                        .padding(.vertical, 4)

                        HStack {
                            Image(systemName: "phone")
                                .foregroundStyle(.secondary)
                            Text(contact.phone)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Care Team

struct CareTeamView: View {
    let members: [CareTeamMember]

    var body: some View {
        List {
            if members.isEmpty {
                Section {
                    Text("No care team members on file.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(members) { member in
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(roleColor(member.role).opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: roleIcon(member.role))
                                    .foregroundStyle(roleColor(member.role))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.name)
                                    .font(.headline)
                                Text(member.role)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let org = member.organization {
                                    Text(org)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            if let phone = member.phone {
                                Button {
                                    if let url = URL(string: "tel:\(phone.filter { $0.isNumber })") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "phone.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.cbTeal)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Care Team")
        .navigationBarTitleDisplayMode(.large)
    }

    private func roleIcon(_ role: String) -> String {
        let r = role.lowercased()
        if r.contains("doctor") || r.contains("neurolog") || r.contains("cardiolog") || r.contains("physician") { return "stethoscope" }
        if r.contains("nurse") { return "cross.vial.fill" }
        if r.contains("therapist") || r.contains("pt") || r.contains("physical") { return "figure.walk" }
        if r.contains("speech") { return "waveform.and.mic" }
        if r.contains("diet") || r.contains("nutrition") { return "fork.knife" }
        if r.contains("caregiver") { return "heart.fill" }
        return "person.crop.circle"
    }

    private func roleColor(_ role: String) -> Color {
        let r = role.lowercased()
        if r.contains("doctor") || r.contains("neurolog") || r.contains("physician") || r.contains("cardiolog") { return .blue }
        if r.contains("nurse") || r.contains("caregiver") { return Color.cbPrimary }
        if r.contains("therapist") || r.contains("physical") { return Color.cbAmber }
        if r.contains("speech") { return Color.cbTeal }
        return .purple
    }
}

// MARK: - Accessibility Settings

struct AccessibilitySettingsView: View {
    @AppStorage("a11y_largeText") private var largeText = false
    @AppStorage("a11y_highContrast") private var highContrast = false
    @AppStorage("a11y_boldText") private var boldText = false
    @AppStorage("a11y_reduceMotion") private var reduceMotion = false
    @AppStorage("a11y_voiceOverHints") private var voiceOverHints = true
    @AppStorage("a11y_haptics") private var haptics = true

    var body: some View {
        List {
            Section {
                Text("These settings help make the CareBridge app easier to use. Changes take effect immediately across the whole app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Preview")
                    .font(.body)
                    .fontWeight(boldText ? .bold : .regular)
                    .dynamicTypeSize(largeText ? DynamicTypeSize.accessibility2 : DynamicTypeSize.medium)
                    .contrast(highContrast ? 1.18 : 1.0)
            }

            Section("Visual") {
                Toggle(isOn: $largeText) {
                    Label("Larger Text", systemImage: "textformat.size.larger")
                }
                Toggle(isOn: $highContrast) {
                    Label("High Contrast", systemImage: "circle.lefthalf.filled")
                }
                Toggle(isOn: $boldText) {
                    Label("Bold Text", systemImage: "bold")
                }
            }

            Section("Motion & Interaction") {
                Toggle(isOn: $reduceMotion) {
                    Label("Reduce Motion", systemImage: "wave.3.right")
                }
                Toggle(isOn: $haptics) {
                    Label("Haptic Feedback", systemImage: "hand.tap.fill")
                }
                .onChange(of: haptics) { _, enabled in
                    if enabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                }
            }

            Section("Screen Reader") {
                Toggle(isOn: $voiceOverHints) {
                    Label("VoiceOver Hints", systemImage: "speaker.wave.3.fill")
                }
                Text("When enabled, additional descriptions are provided for interactive elements to assist VoiceOver users.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("System Settings") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open iOS Accessibility Settings", systemImage: "gear")
                }
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Notifications Settings

struct NotificationsSettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("notif_caregiverCalls") private var caregiverCallNotifs = true
    @AppStorage("notif_checkinReminder") private var checkinReminder = true
    @AppStorage("notif_medicationReminder") private var medicationReminder = true
    @AppStorage("notif_checkinTime") private var checkinTime = 9 // 9 AM

    @State private var permissionGranted = false
    @State private var medications: [Medication] = []

    private let hours = Array(6...22)
    private var isPatient: Bool { authManager.currentUser?.role != "caregiver" && authManager.currentUser?.role != "organization" }

    var body: some View {
        List {
            if !permissionGranted {
                Section {
                    Button {
                        NotificationsManager.shared.requestAuthorization { granted in
                            permissionGranted = granted
                            if granted { resyncAll() }
                        }
                    } label: {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                    Text("Notifications aren't enabled yet. Tap to allow CareBridge to send reminders and alerts.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Alerts") {
                Toggle(isOn: $caregiverCallNotifs) {
                    Label(isPatient ? "Caregiver Response Alerts" : "Patient Call Alerts", systemImage: "bell.badge.fill")
                }
                Text(isPatient ? "Get notified when your caregiver responds to your call request."
                                : "Get notified instantly when a patient calls for help.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            if isPatient {
                Section("Reminders") {
                    Toggle(isOn: $checkinReminder) {
                        Label("Daily Check-In Reminder", systemImage: "heart.text.square.fill")
                    }
                    .onChange(of: checkinReminder) { _, _ in resyncAll() }

                    if checkinReminder {
                        Picker("Reminder Time", selection: $checkinTime) {
                            ForEach(hours, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .onChange(of: checkinTime) { _, _ in resyncAll() }
                    }

                    Toggle(isOn: $medicationReminder) {
                        Label("Medication Reminders", systemImage: "pills.fill")
                    }
                    .onChange(of: medicationReminder) { _, _ in resyncAll() }
                }
            }

            Section("System") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Manage iOS Notification Permissions", systemImage: "gear")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task { await checkPermissionAndLoad() }
    }

    private func formatHour(_ h: Int) -> String {
        let ampm = h < 12 ? "AM" : "PM"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(display):00 \(ampm)"
    }

    @MainActor
    private func checkPermissionAndLoad() async {
        permissionGranted = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus == .authorized)
            }
        }
        guard isPatient, let token = authManager.token else { return }
        if let pid = try? await APIService.shared.getMyPatient(token: token) {
            medications = (try? await APIService.shared.getMedications(patientId: pid, token: token)) ?? []
        }
        if permissionGranted { resyncAll() }
    }

    private func resyncAll() {
        guard permissionGranted, isPatient else { return }
        NotificationsManager.shared.syncCheckinReminder(enabled: checkinReminder, hour: checkinTime)
        NotificationsManager.shared.syncMedicationReminders(enabled: medicationReminder, medications: medications)
    }
}

// MARK: - Server Settings

struct ServerSettingsView: View {
    @State private var urlText = UserDefaults.standard.string(forKey: APIService.serverURLKey) ?? APIService.defaultServerURL
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                TextField("http://192.168.x.x:3000", text: $urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Backend Server URL")
            } footer: {
                Text("Enter your Mac's local IP address. Run the backend and check the terminal for the line that says \"Local network URL\".")
            }

            Section {
                Button("Save & Reconnect") {
                    let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                    UserDefaults.standard.set(trimmed.isEmpty ? nil : trimmed, forKey: APIService.serverURLKey)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                }
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Reset to Default", role: .destructive) {
                    urlText = APIService.defaultServerURL
                    UserDefaults.standard.removeObject(forKey: APIService.serverURLKey)
                }
            }

            if saved {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Saved — restart the app to reconnect.")
                    }
                }
            }
        }
        .navigationTitle("Server Connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}
