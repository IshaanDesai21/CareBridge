import SwiftUI

struct AddMedicationView: View {
    let patientId: Int
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var onAdd: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Medication Details")) {
                    TextField("Medication Name (e.g. Lisinopril)", text: $name)
                    TextField("Dosage (e.g. 10mg)", text: $dosage)
                    TextField("Frequency (e.g. Once daily)", text: $frequency)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await addMedication() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    @MainActor
    private func addMedication() async {
        guard let token = authManager.token else { return }
        isSubmitting = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.addMedication(
                patientId: patientId,
                name: name.trimmingCharacters(in: .whitespaces),
                dosage: dosage.trimmingCharacters(in: .whitespaces),
                frequency: frequency.trimmingCharacters(in: .whitespaces),
                token: token
            )
            onAdd?()
            dismiss()
        } catch {
            errorMessage = "Failed to add medication. Please try again."
        }
        
        isSubmitting = false
    }
}
