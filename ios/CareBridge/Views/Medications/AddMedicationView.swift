import SwiftUI

struct AddMedicationView: View {
    let patientId: Int
    var autoOpenScanner: Bool = false
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var accessibility = AccessibilityManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var instructions = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @State private var showScanner = false
    @State private var isParsingScan = false
    @State private var scanConfirmed = false
    @State private var scanCouldNotIdentify = false
    @State private var validationWarning: String? = nil

    var onAdd: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        accessibility.hapticImpact(.light)
                        showScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Medication Label")
                            Spacer()
                            if isParsingScan { ProgressView() }
                        }
                    }
                    .disabled(isParsingScan)
                    .accessibilityHint(accessibility.hint("Opens the camera to automatically read a medication label"))

                    if scanConfirmed {
                        Label("Filled in automatically from scan — review before adding", systemImage: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(Color.cbGreen)
                    }
                    if let warning = validationWarning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if scanCouldNotIdentify {
                        Label("Couldn't recognize a medication on that label. Try again or enter details manually.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section(header: Text("Medication Details")) {
                    TextField("Medication Name (e.g. Lisinopril)", text: $name)
                    TextField("Dosage (e.g. 10mg)", text: $dosage)
                    TextField("Frequency (e.g. Once daily)", text: $frequency)
                    TextField("Instructions (optional)", text: $instructions, axis: .vertical)
                        .lineLimit(1...3)
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
                        accessibility.hapticImpact(.medium)
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
            .fullScreenCover(isPresented: $showScanner) {
                MedicationScannerScreen(
                    onCaptured: { text in
                        showScanner = false
                        Task { await handleScan(text) }
                    },
                    onCancel: { showScanner = false }
                )
            }
            .onAppear {
                if autoOpenScanner { showScanner = true }
            }
        }
    }

    @MainActor
    private func handleScan(_ scannedText: String) async {
        guard let token = authManager.token else { return }
        isParsingScan = true
        scanConfirmed = false
        scanCouldNotIdentify = false
        validationWarning = nil
        do {
            let result = try await APIService.shared.parseMedicationLabel(text: scannedText, token: token)
            if result.isValid {
                name = result.canonicalName ?? result.name ?? ""
                if let d = result.dosage { dosage = d }
                if let f = result.frequency { frequency = f }
                if let i = result.instructions { instructions = i }
                scanConfirmed = true
                validationWarning = nil
                accessibility.hapticNotification(.success)
            } else if result.name != nil {
                name = result.name ?? ""
                if let d = result.dosage { dosage = d }
                if let f = result.frequency { frequency = f }
                scanConfirmed = true
                validationWarning = "Medication not found in standard database — please verify before saving"
                accessibility.hapticNotification(.warning)
            } else {
                scanCouldNotIdentify = true
                accessibility.hapticNotification(.error)
            }
        } catch {
            scanCouldNotIdentify = true
            accessibility.hapticNotification(.error)
        }
        isParsingScan = false
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
                instructions: instructions.trimmingCharacters(in: .whitespaces).isEmpty ? nil : instructions.trimmingCharacters(in: .whitespaces),
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
