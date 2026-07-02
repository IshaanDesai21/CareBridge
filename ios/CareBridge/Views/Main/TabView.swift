import SwiftUI
import Charts

// MARK: - Root tab router

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        Group {
            switch authManager.currentUser?.role {
            case "caregiver", "organization":
                TabView {
                    CaregiverView()
                        .environmentObject(authManager)
                        .tabItem { Label("Patients", systemImage: "person.2.fill") }
                    ScanMedicationView()
                        .tabItem { Label("Scan Med", systemImage: "camera.fill") }
                    ProfileView()
                        .environmentObject(authManager)
                        .tabItem { Label("Profile", systemImage: "person.fill") }
                }
                .tint(Color.cbPrimary)

            case "family":
                TabView {
                    FamilyPortalView()
                        .environmentObject(authManager)
                        .tabItem { Label("Overview", systemImage: "heart.text.square.fill") }
                    ProfileView()
                        .environmentObject(authManager)
                        .tabItem { Label("Profile", systemImage: "person.fill") }
                }
                .tint(Color.cbPrimary)

            default: // patient
                TabView {
                    HomeView()
                        .environmentObject(authManager)
                        .tabItem { Label("Home", systemImage: "house.fill") }
                    WellnessView()
                        .environmentObject(authManager)
                        .tabItem { Label("Wellness", systemImage: "heart.fill") }
                    MedicationsView()
                        .environmentObject(authManager)
                        .tabItem { Label("Medications", systemImage: "pill.fill") }
                    ProfileView()
                        .environmentObject(authManager)
                        .tabItem { Label("Profile", systemImage: "person.fill") }
                }
                .tint(Color.cbPrimary)
            }
        }
    }
}

// MARK: - Caregiver view

struct CaregiverView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var alerts: [PatientAlert] = []
    @State private var patients: [Patient] = []
    @State private var loading = true

    var pendingAlerts: [PatientAlert] { alerts.filter { !$0.acknowledged } }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading…").foregroundStyle(.secondary).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !pendingAlerts.isEmpty {
                            Section {
                                ForEach(pendingAlerts) { alert in
                                    AlertRow(alert: alert) { Task { await acknowledge(alert) } }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "bell.badge.fill").foregroundStyle(.red)
                                    Text("Patient Alerts (\(pendingAlerts.count))")
                                        .foregroundStyle(.red).fontWeight(.bold)
                                }
                            }
                        }

                        Section("Patients") {
                            if patients.isEmpty {
                                Text("No patients yet").foregroundStyle(.secondary).font(.subheadline)
                            } else {
                                ForEach(patients) { patient in
                                    NavigationLink(destination: PatientDetailCaregiverView(patient: patient)
                                        .environmentObject(authManager)) {
                                        PatientRow(patient: patient)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NotificationBellButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await load() }
        .onChange(of: LiveNotificationsManager.shared.lastReceivedAt) { _, _ in Task { await load() } }
    }

    @MainActor private func load() async {
        guard let token = authManager.token else { return }
        loading = true
        alerts = (try? await APIService.shared.getAlerts(token: token)) ?? []
        patients = (try? await APIService.shared.getPatients(token: token)) ?? []
        loading = false
    }

    @MainActor private func acknowledge(_ alert: PatientAlert) async {
        guard let token = authManager.token else { return }
        try? await APIService.shared.acknowledgeAlert(id: alert.id, token: token)
        alerts = alerts.map {
            $0.id == alert.id
                ? PatientAlert(id: $0.id, patientName: $0.patientName, message: $0.message,
                               isUrgent: $0.isUrgent, isAcknowledged: 1, createdAt: $0.createdAt)
                : $0
        }
    }
}

struct AlertRow: View {
    let alert: PatientAlert
    let onAcknowledge: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.urgent ? "exclamationmark.triangle.fill" : "phone.fill")
                .foregroundStyle(alert.urgent ? .red : .orange)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 3) {
                Text(alert.patientName ?? "Patient")
                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.primary)
                Text(alert.message)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            Spacer()

            Button("Done") { onAcknowledge() }
                .font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.cbPrimary.opacity(0.1))
                .foregroundStyle(Color.cbPrimary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

struct PatientRow: View {
    let patient: Patient

    private var scoreColor: Color {
        patient.wellnessScore >= 80 ? Color.cbGreen :
        patient.wellnessScore >= 60 ? Color.cbAmber : Color.cbRed
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(scoreColor.opacity(0.15)).frame(width: 44, height: 44)
                Text(String((patient.firstName ?? "?").prefix(1)))
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(scoreColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(patient.firstName ?? "") \(patient.lastName ?? "")")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                Text(patient.wellnessScore >= 80 ? "Excellent" :
                     patient.wellnessScore >= 60 ? "Moderate" : "Needs Attention")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(patient.wellnessScore)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(scoreColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Caregiver patient detail

struct PatientDetailCaregiverView: View {
    let patient: Patient
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var wellness: [WellnessCheckin] = []
    @State private var medications: [Medication] = []
    @State private var notes: [CareNote] = []
    @State private var details: PhysicalDetails?
    @State private var selectedTab = 0
    @State private var showCheckin = false
    @State private var loading = true
    @State private var familyCode: String = ""
    @State private var showAddMedication = false
    @State private var showEditPhysical = false

    private var scoreColor: Color {
        patient.wellnessScore >= 80 ? Color.cbGreen :
        patient.wellnessScore >= 60 ? Color.cbAmber : Color.cbRed
    }

    var body: some View {
        Group {
            if loading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading…").foregroundStyle(.secondary).font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Patient card
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(scoreColor.opacity(0.15)).frame(width: 56, height: 56)
                                Text(String((patient.firstName ?? "?").prefix(1)))
                                    .font(.system(size: 22, weight: .bold)).foregroundStyle(scoreColor)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(patient.firstName ?? "") \(patient.lastName ?? "")")
                                    .font(.title3).fontWeight(.bold)
                                Text(patient.wellnessScore >= 80 ? "Excellent" :
                                     patient.wellnessScore >= 60 ? "Moderate" : "Needs Attention")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Text("\(patient.wellnessScore)")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(scoreColor)
                                Text("Score").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                        Button(action: { showCheckin = true }) {
                            Label("Submit Wellness Check-in", systemImage: "heart.text.square.fill")
                                .font(.headline).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.cbPrimary)
                                .cornerRadius(12)
                        }

                        Picker("", selection: $selectedTab) {
                            Text("Check-ins").tag(0)
                            Text("Medications").tag(1)
                            Text("Notes").tag(2)
                            Text("Physical").tag(3)
                            Text("Family").tag(4)
                        }
                        .pickerStyle(.segmented)

                        switch selectedTab {
                        case 0: wellnessSection
                        case 1: medsSection
                        case 2: notesSection
                        case 3: physicalSection
                        default: familySection
                        }
                    }
                    .padding(16)
                }
                .refreshable { await load() }
            }
        }
        .background(Color.cbBackground.ignoresSafeArea())
        .navigationTitle("\(patient.firstName ?? "") \(patient.lastName ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckin, onDismiss: { Task { await load() } }) {
            WellnessCheckinView(patientId: patient.id).environmentObject(authManager)
        }
        .sheet(isPresented: $showAddMedication, onDismiss: { Task { await load() } }) {
            AddMedicationView(patientId: patient.id, onAdd: { Task { await load() } })
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showEditPhysical, onDismiss: { Task { await load() } }) {
            EditPhysicalDetailsView(patientId: patient.id, existing: details)
                .environmentObject(authManager)
        }
        .task { await load() }
    }

    @ViewBuilder private var wellnessSection: some View {
        if wellness.isEmpty {
            cgEmptyCard("No check-ins recorded yet")
        } else {
            VStack(spacing: 6) {
                // Header row
                HStack(spacing: 8) {
                    Text("Date").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                        .frame(width: 68, alignment: .leading)
                    Text("Energy").font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                    Text("Mood").font(.caption).fontWeight(.bold).foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                    Text("Pain").font(.caption).fontWeight(.bold).foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.cbBorder.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                ForEach(wellness.prefix(14)) { entry in
                    HStack(spacing: 8) {
                        Text(shortDate(entry.date)).font(.caption).foregroundStyle(.secondary)
                            .frame(width: 68, alignment: .leading)
                        cgMetric(entry.energy, color: .orange)
                        cgMetric(entry.mood, color: .blue)
                        cgMetric(entry.pain, color: .red)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func cgMetric(_ value: Int?, color: Color) -> some View {
        Text(value.map { "\($0)" } ?? "—")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(color).frame(maxWidth: .infinity)
    }

    @ViewBuilder private var medsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Medications")
                    .font(.headline)
                Spacer()
                Button {
                    showAddMedication = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline).fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 4)

            if medications.isEmpty {
                cgEmptyCard("No medications recorded")
            } else {
                VStack(spacing: 8) {
                    ForEach(medications) { med in
                        HStack(spacing: 12) {
                            Image(systemName: "pills.fill").foregroundStyle(Color.cbPrimary).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(med.name).font(.subheadline).fontWeight(.semibold)
                                Text([med.dosage, med.frequency].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    @ViewBuilder private var notesSection: some View {
        if notes.isEmpty {
            cgEmptyCard("No care notes yet")
        } else {
            VStack(spacing: 8) {
                ForEach(notes.prefix(10)) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(note.noteType.capitalized)
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.cbPrimary.opacity(0.1))
                                .foregroundStyle(Color.cbPrimary).clipShape(Capsule())
                            Spacer()
                            Text(shortDate(note.createdAt)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(note.content).font(.subheadline).lineLimit(3)
                    }
                    .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func cgEmptyCard(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(20)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var physicalSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Physical Details").font(.headline)
                Spacer()
                Button { showEditPhysical = true } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline).fontWeight(.semibold)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.cbPrimary.opacity(0.1))
                        .foregroundStyle(Color.cbPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)

            if let d = details {
                HStack(spacing: 12) {
                    metricCard(title: "Gender", value: d.gender?.capitalized ?? "—", icon: "person.fill")
                    metricCard(title: "Height", value: d.heightFormatted, icon: "ruler.fill")
                    metricCard(title: "Weight", value: d.weightFormatted, icon: "scalemass.fill")
                }

                // Weight trend chart
                let weightPoints = wellness.compactMap { c -> (String, Double)? in
                    guard let w = c.weight else { return nil }
                    return (String(c.date.prefix(10)), w)
                }.reversed() as [(String, Double)]

                if !weightPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight Trend")
                            .font(.subheadline).fontWeight(.semibold)
                            .padding(.horizontal, 4)
                        Chart {
                            ForEach(Array(weightPoints.enumerated()), id: \.offset) { idx, pt in
                                LineMark(
                                    x: .value("Date", idx),
                                    y: .value("kg", pt.1)
                                )
                                .foregroundStyle(Color.cbPrimary)
                                .interpolationMethod(.catmullRom)
                                PointMark(
                                    x: .value("Date", idx),
                                    y: .value("kg", pt.1)
                                )
                                .foregroundStyle(Color.cbPrimary)
                                .annotation(position: .top) {
                                    Text(String(format: "%.1f", pt.1))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading) { v in
                                AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))kg").font(.caption2) } }
                                AxisGridLine()
                            }
                        }
                        .frame(height: 140)
                        .padding(.horizontal, 4)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                if let vision = d.visionScore, !vision.isEmpty {
                    infoCard(title: "Eyesight", text: vision, icon: "eye.fill", color: .cbTeal)
                }
                if let hearing = d.hearingNotes, !hearing.isEmpty {
                    infoCard(title: "Hearing", text: hearing, icon: "ear", color: .cbAmber)
                }
                if let ai = d.aiCompanionName, !ai.isEmpty {
                    let companionText = "\(patient.firstName ?? "Patient") talks to \(ai)."
                    infoCard(title: "AI Companion", text: companionText, icon: "waveform", color: .purple)
                }
                if let history = d.medicalHistory, !history.isEmpty {
                    infoCard(title: "Medical History", text: history, icon: "doc.text.fill", color: .blue)
                }
                if let diagnoses = d.diagnoses, !diagnoses.isEmpty {
                    infoCard(title: "Diagnoses", text: diagnoses.joined(separator: ", "), icon: "cross.case.fill", color: .red)
                }
                if let allergies = d.allergies, !allergies.isEmpty {
                    infoCard(title: "Allergies", text: allergies.joined(separator: ", "), icon: "exclamationmark.triangle.fill", color: .orange)
                }
            } else {
                cgEmptyCard("No physical details on file — tap Edit to add")
            }
        }
    }

    @ViewBuilder private var familySection: some View {
        VStack(spacing: 12) {
            // Family join code card
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "qrcode").foregroundStyle(Color.cbPrimary)
                    Text("Patient Link Code").font(.headline)
                    Spacer()
                }

                let code = familyCode.isEmpty ? "Loading…" : familyCode
                Text(code)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.cbPrimary)
                    .padding(.vertical, 8)

                Text("Share this code with family members so they can link to this patient in the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy Code", systemImage: "doc.on.doc")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.cbPrimary.opacity(0.1))
                        .foregroundStyle(Color.cbPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)

            // Emergency contacts
            if let contacts = details?.emergencyContacts, !contacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emergency Contacts")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    ForEach(contacts) { contact in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(contact.isPrimary == true ? Color.cbPrimary.opacity(0.15) : Color.secondary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "person.fill")
                                    .foregroundStyle(contact.isPrimary == true ? Color.cbPrimary : .secondary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(contact.name).font(.subheadline).fontWeight(.semibold)
                                    if contact.isPrimary == true {
                                        Text("PRIMARY")
                                            .font(.system(size: 8, weight: .bold))
                                            .padding(.horizontal, 5).padding(.vertical, 2)
                                            .background(Color.cbPrimary.opacity(0.15))
                                            .foregroundStyle(Color.cbPrimary)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(contact.relation).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                if let url = URL(string: "tel:\(contact.phone.filter { $0.isNumber })") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "phone.circle.fill").font(.system(size: 30)).foregroundStyle(Color.cbGreen)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.cbPrimary).font(.title2)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline).fontWeight(.semibold).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private func infoCard(title: String, text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).fontWeight(.bold)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }


    private func shortDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: str) { let o = DateFormatter(); o.dateStyle = .short; return o.string(from: d) }
        return String(str.prefix(10))
    }

    @MainActor private func load() async {
        guard let token = authManager.token else { return }
        loading = true
        async let w = APIService.shared.getWellnessHistory(patientId: patient.id, token: token)
        async let m = APIService.shared.getMedications(patientId: patient.id, token: token)
        async let n = APIService.shared.getCareNotes(patientId: patient.id, token: token)
        async let d = APIService.shared.getPatientDetails(patientId: patient.id, token: token)
        async let fc = APIService.shared.getPatientFamilyCode(patientId: patient.id, token: token)
        wellness = (try? await w) ?? []
        medications = (try? await m) ?? []
        notes = (try? await n) ?? []
        details = try? await d
        familyCode = (try? await fc) ?? ""
        loading = false
    }
}

// MARK: - Family portal view

struct FamilyPortalView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var patients: [Patient] = []
    @State private var selectedPatient: Patient?
    @State private var wellness: [WellnessCheckin] = []
    @State private var medications: [Medication] = []
    @State private var notes: [CareNote] = []
    @State private var loading = true
    @State private var loadingDetail = false
    @State private var selectedTab = 0

    private var scoreColor: Color {
        let s = selectedPatient?.wellnessScore ?? 0
        return s >= 80 ? Color.cbGreen : s >= 60 ? Color.cbAmber : Color.cbRed
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading…").foregroundStyle(.secondary).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let p = selectedPatient {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Patient switcher (shown when multiple patients linked)
                            if patients.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(patients) { pt in
                                            Button(action: { selectPatient(pt) }) {
                                                Text("\(pt.firstName ?? "") \(pt.lastName ?? "")")
                                                    .font(.subheadline).fontWeight(.semibold)
                                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                                    .background(selectedPatient?.id == pt.id
                                                        ? Color.cbPrimary : Color.white)
                                                    .foregroundStyle(selectedPatient?.id == pt.id
                                                        ? .white : Color.cbPrimary)
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(Color.cbPrimary, lineWidth: 1.5))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }

                            // Patient card
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle().fill(scoreColor.opacity(0.15)).frame(width: 56, height: 56)
                                    Text(String((p.firstName ?? "?").prefix(1)))
                                        .font(.system(size: 22, weight: .bold)).foregroundStyle(scoreColor)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(p.firstName ?? "") \(p.lastName ?? "")")
                                        .font(.title3).fontWeight(.bold).foregroundStyle(.primary)
                                    Text(p.wellnessScore >= 80 ? "Excellent" :
                                         p.wellnessScore >= 60 ? "Moderate" : "Needs Attention")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(spacing: 2) {
                                    Text("\(p.wellnessScore)")
                                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                                        .foregroundStyle(scoreColor)
                                    Text("Score").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)

                            Picker("", selection: $selectedTab) {
                                Text("Check-ins").tag(0)
                                Text("Medications").tag(1)
                                Text("Care Notes").tag(2)
                            }
                            .pickerStyle(.segmented)

                            if loadingDetail {
                                ProgressView().padding()
                            } else {
                                switch selectedTab {
                                case 0: wellnessSection
                                case 1: medsSection
                                default: notesSection
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await loadDetail(p) }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 56)).foregroundStyle(Color.cbBorder)
                        Text("No patient linked").font(.headline)
                        Text("Ask your family member's care team for a join code.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationTitle(selectedPatient.map { "\($0.firstName ?? "") \($0.lastName ?? "")" } ?? "Family")
        }
        .task { await load() }
    }

    private func selectPatient(_ p: Patient) {
        selectedPatient = p
        Task { await loadDetail(p) }
    }

    private func computeScore(_ c: WellnessCheckin) -> Int {
        let e = c.energy ?? 5, f = c.fatigue ?? 5, p = c.pain ?? 5
        let m = c.mood ?? 5, s = c.sleepQuality ?? 5, b = c.breathing ?? 5
        let mo = c.mobility ?? 5, ba = c.balance ?? 5, sp = c.speechClarity ?? 5
        let ap = c.appetite ?? 5, hy = c.hydration ?? 5, sw = c.swallowingDifficulty ?? 5
        let total = Double(e) + Double(11-f) + Double(11-p) + Double(m) + Double(s) + Double(b)
            + Double(mo) + Double(ba) + Double(sp) + Double(ap) + Double(hy) + Double(11-sw)
        return min(100, max(0, Int((total / 12.0) * 10.0)))
    }

    private func scoreColor(_ score: Int) -> Color {
        score >= 80 ? Color.cbGreen : score >= 60 ? Color.cbAmber : Color.cbRed
    }

    @ViewBuilder private var wellnessSection: some View {
        if wellness.isEmpty {
            familyEmptyCard("No check-ins recorded yet")
        } else {
            VStack(spacing: 12) {
                // Score trend chart
                let reversed = Array(wellness.prefix(14).reversed())
                if reversed.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wellness Score Trend")
                            .font(.subheadline).fontWeight(.semibold).padding(.horizontal, 4)
                        Chart {
                            ForEach(Array(reversed.enumerated()), id: \.offset) { idx, entry in
                                let score = Double(computeScore(entry))
                                LineMark(x: .value("Day", idx), y: .value("Score", score))
                                    .foregroundStyle(Color.cbPrimary).interpolationMethod(.catmullRom)
                                AreaMark(x: .value("Day", idx), y: .value("Score", score))
                                    .foregroundStyle(Color.cbPrimary.opacity(0.08))
                                PointMark(x: .value("Day", idx), y: .value("Score", score))
                                    .foregroundStyle(Color.cbPrimary)
                                    .symbolSize(30)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(values: [0, 50, 100]) { v in
                                AxisValueLabel { if let d = v.as(Int.self) { Text("\(d)").font(.caption2) } }
                                AxisGridLine()
                            }
                        }
                        .frame(height: 110)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }

                // Recent check-in cards
                ForEach(wellness.prefix(7)) { entry in
                    let score = computeScore(entry)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(shortDate(entry.date))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(score)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(scoreColor(score))
                            Text("/ 100")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 6) {
                            familyMetricPill("Energy", value: entry.energy, color: .orange)
                            familyMetricPill("Mood", value: entry.mood, color: .blue)
                            familyMetricPill("Pain", value: entry.pain, color: .red)
                            familyMetricPill("Sleep", value: entry.sleepQuality, color: .purple)
                            familyMetricPill("Mobility", value: entry.mobility, color: .green)
                            familyMetricPill("Hydration", value: entry.hydration, color: .cyan)
                        }

                        if let n = entry.notes, !n.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text").font(.caption2).foregroundStyle(.secondary)
                                Text(n).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    private func familyMetricPill(_ label: String, value: Int?, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Text(value.map { "\($0)" } ?? "—")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    @ViewBuilder private var medsSection: some View {
        if medications.isEmpty {
            familyEmptyCard("No medications recorded")
        } else {
            VStack(spacing: 8) {
                ForEach(medications) { med in
                    HStack(spacing: 12) {
                        Image(systemName: "pills.fill").foregroundStyle(Color.cbPrimary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.name).font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                            Text([med.dosage, med.frequency].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder private var notesSection: some View {
        if notes.isEmpty {
            familyEmptyCard("No care notes yet")
        } else {
            VStack(spacing: 8) {
                ForEach(notes.prefix(10)) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(note.noteType.capitalized)
                                .font(.caption).fontWeight(.bold)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.cbPrimary.opacity(0.1))
                                .foregroundStyle(Color.cbPrimary).clipShape(Capsule())
                            Spacer()
                            Text(shortDate(note.createdAt)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(note.content).font(.subheadline).foregroundStyle(.primary).lineLimit(3)
                    }
                    .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func familyEmptyCard(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).padding(20)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func shortDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: str) { let o = DateFormatter(); o.dateStyle = .short; return o.string(from: d) }
        return String(str.prefix(10))
    }

    @MainActor private func load() async {
        guard let token = authManager.token else { return }
        loading = true
        patients = (try? await APIService.shared.getPatients(token: token)) ?? []
        if let first = patients.first {
            selectedPatient = first
            await loadDetail(first)
        }
        loading = false
    }

    @MainActor private func loadDetail(_ p: Patient) async {
        guard let token = authManager.token else { return }
        loadingDetail = true
        async let w = APIService.shared.getWellnessHistory(patientId: p.id, token: token)
        async let m = APIService.shared.getMedications(patientId: p.id, token: token)
        async let n = APIService.shared.getCareNotes(patientId: p.id, token: token)
        wellness = (try? await w) ?? []
        medications = (try? await m) ?? []
        notes = (try? await n) ?? []
        loadingDetail = false
    }
}

// MARK: - Scan medication placeholder

struct ScanMedicationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var patients: [Patient] = []
    @State private var loading = true
    @State private var selectedPatient: Patient?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if patients.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 56)).foregroundStyle(Color.cbTeal)
                        Text("No patients yet").font(.headline)
                        Text("Add a patient before scanning medications for them.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("Choose the patient this medication belongs to. Then point the camera at the label — it fills in the details automatically.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Section("Patients") {
                            ForEach(patients) { patient in
                                Button {
                                    selectedPatient = patient
                                } label: {
                                    PatientRow(patient: patient)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationTitle("Scan Medication")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPatient) { patient in
                AddMedicationView(patientId: patient.id, autoOpenScanner: true)
                    .environmentObject(authManager)
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        guard let token = authManager.token else { loading = false; return }
        patients = (try? await APIService.shared.getPatients(token: token)) ?? []
        loading = false
    }
}

// MARK: - Edit Physical Details

struct EditPhysicalDetailsView: View {
    let patientId: Int
    let existing: PhysicalDetails?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var gender = ""
    @State private var heightCm = ""
    @State private var weightKg = ""
    @State private var hearingNotes = ""
    @State private var visionScore = ""
    @State private var medicalHistory = ""
    @State private var diagnosesText = ""
    @State private var allergiesText = ""
    @State private var aiCompanionName = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let genderOptions = ["male", "female", "other", "prefer not to say"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    Picker("Gender", selection: $gender) {
                        Text("Not specified").tag("")
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option.capitalized).tag(option)
                        }
                    }

                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", text: $heightCm)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm").foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", text: $weightKg)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                }

                Section("Senses") {
                    LabeledContent("Vision") {
                        TextField("e.g. 20/20, wears glasses", text: $visionScore)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hearing Notes")
                        TextEditor(text: $hearingNotes)
                            .frame(minHeight: 60)
                    }
                }

                Section("Medical") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Medical History")
                        TextEditor(text: $medicalHistory)
                            .frame(minHeight: 60)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Diagnoses").font(.subheadline)
                        TextField("Comma-separated, e.g. Diabetes, Hypertension", text: $diagnosesText)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Allergies").font(.subheadline)
                        TextField("Comma-separated, e.g. Penicillin, Peanuts", text: $allergiesText)
                    }
                }

                Section("AI Companion") {
                    LabeledContent("Companion Name") {
                        TextField("e.g. James, Rose, Alex", text: $aiCompanionName)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("The AI companion will use this name when chatting with the patient.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.subheadline)
                    }
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        guard let d = existing else { return }
        gender = d.gender ?? ""
        heightCm = d.heightCm.map { String(format: "%.1f", $0) } ?? ""
        weightKg = d.weightKg.map { String(format: "%.1f", $0) } ?? ""
        hearingNotes = d.hearingNotes ?? ""
        visionScore = d.visionScore ?? ""
        medicalHistory = d.medicalHistory ?? ""
        diagnosesText = d.diagnoses?.joined(separator: ", ") ?? ""
        allergiesText = d.allergies?.joined(separator: ", ") ?? ""
        aiCompanionName = d.aiCompanionName ?? ""
    }

    @MainActor private func save() async {
        guard let token = authManager.token else { return }
        isSaving = true
        errorMessage = nil

        let parsedHeight = heightCm.isEmpty ? nil : Double(heightCm.replacingOccurrences(of: ",", with: "."))
        let parsedWeight = weightKg.isEmpty ? nil : Double(weightKg.replacingOccurrences(of: ",", with: "."))
        let parsedDiagnoses = diagnosesText.isEmpty ? nil : diagnosesText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let parsedAllergies = allergiesText.isEmpty ? nil : allergiesText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        do {
            try await APIService.shared.updatePatientDetails(
                patientId: patientId,
                gender: gender.isEmpty ? nil : gender,
                heightCm: parsedHeight,
                weightKg: parsedWeight,
                hearingNotes: hearingNotes.isEmpty ? nil : hearingNotes,
                visionScore: visionScore.isEmpty ? nil : visionScore,
                medicalHistory: medicalHistory.isEmpty ? nil : medicalHistory,
                diagnoses: parsedDiagnoses,
                allergies: parsedAllergies,
                aiCompanionName: aiCompanionName.isEmpty ? nil : aiCompanionName,
                token: token
            )
            dismiss()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }
        isSaving = false
    }
}

// MARK: - Previews

#Preview { MainTabView().environmentObject(AuthenticationManager()) }
