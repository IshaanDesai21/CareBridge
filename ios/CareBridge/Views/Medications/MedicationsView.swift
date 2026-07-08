import SwiftUI

struct MedicationsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var medications: [Medication] = []
    @State private var isLoading = true
    @State private var patientId: Int? = nil
    @State private var showVerification = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if medications.isEmpty {
                    EmptyStateView(
                        icon: "pill",
                        title: "No Medications",
                        description: "Your medications will appear here"
                    )
                } else {
                    List(medications) { medication in
                        MedicationRow(medication: medication)
                    }
                }
            }
            .navigationTitle("Medications")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showVerification = true
                    } label: {
                        Label("Verify Pills", systemImage: "camera.viewfinder")
                    }
                    .disabled(medications.isEmpty || patientId == nil)
                }
            }
            .sheet(isPresented: $showVerification) {
                if let pid = patientId {
                    PillVerificationView(patientId: pid, medications: medications)
                }
            }
            .task {
                await loadMedications()
            }
        }
    }

    private func loadMedications() async {
        guard let token = authManager.token else { return }
        isLoading = true
        do {
            let pid = try await APIService.shared.getMyPatient(token: token)
            patientId = pid
            medications = try await APIService.shared.getMedications(patientId: pid, token: token)
        } catch {
            print("Failed to load medications: \(error)")
        }
        isLoading = false
    }
}

struct MedicationRow: View {
    let medication: Medication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(medication.name)
                .font(.headline)
            
            if let dosage = medication.dosage {
                Text(dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let frequency = medication.frequency {
                Label(frequency, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MedicationsView()
        .environmentObject(AuthenticationManager())
}
