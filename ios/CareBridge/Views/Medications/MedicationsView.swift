import SwiftUI

struct MedicationsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var medications: [Medication] = []
    @State private var isLoading = true
    
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
                        // Add medication
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await loadMedications()
            }
        }
    }
    
    private func loadMedications() async {
        isLoading = true
        // Load from API
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
