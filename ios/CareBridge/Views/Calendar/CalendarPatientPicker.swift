import SwiftUI

/// Loads the viewer's patients. Exactly one → shows `content` directly;
/// several → a list that pushes `content` for the chosen patient.
struct CalendarPatientPicker<Content: View>: View {
    @EnvironmentObject var authManager: AuthenticationManager
    let content: (Patient) -> Content

    @State private var patients: [Patient] = []
    @State private var loading = true
    @State private var errorMessage: String?

    init(@ViewBuilder content: @escaping (Patient) -> Content) {
        self.content = content
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't load patients", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") { Task { await load() } }
                    }
                } else if patients.count == 1, let only = patients.first {
                    content(only)
                } else if patients.isEmpty {
                    ContentUnavailableView("No patients", systemImage: "person.2.slash",
                                           description: Text("Patients you care for will appear here."))
                } else {
                    List(patients) { patient in
                        NavigationLink {
                            content(patient)
                        } label: {
                            PatientRow(patient: patient)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle("Calendar")
                    .refreshable { await load() }
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
        }
        .task { await load() }
    }

    @MainActor private func load() async {
        guard let token = authManager.token else { return }
        do {
            patients = try await APIService.shared.getPatients(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
