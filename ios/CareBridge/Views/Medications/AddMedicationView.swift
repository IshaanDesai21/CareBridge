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
    @State private var scanCouldNotIdentify = false
    @State private var validationWarning: String? = nil

    // After a successful scan, hold the result here and show the confirm sheet.
    @State private var pendingScan: ScannedMedication? = nil
    @State private var showScanConfirm = false

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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        accessibility.hapticImpact(.medium)
                        Task { await addMedication(name: name, dosage: dosage, frequency: frequency, instructions: instructions) }
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
            .sheet(isPresented: $showScanConfirm) {
                if let scan = pendingScan {
                    ScanConfirmSheet(
                        scan: scan,
                        patientId: patientId,
                        onSuccess: {
                            onAdd?()
                            dismiss()
                        }
                    )
                    .environmentObject(authManager)
                }
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
        scanCouldNotIdentify = false
        validationWarning = nil
        do {
            let result = try await APIService.shared.parseMedicationLabel(text: scannedText, token: token)
            if result.isValid {
                // RxNorm-validated — go straight to confirm+save sheet
                pendingScan = result
                showScanConfirm = true
                accessibility.hapticNotification(.success)
            } else if result.name != nil {
                // Name extracted but not in RxNorm — fall back to form so caregiver can review
                name = result.name ?? ""
                if let d = result.dosage { dosage = d }
                if let f = result.frequency { frequency = f }
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
    func addMedication(name: String, dosage: String, frequency: String, instructions: String) async {
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

// MARK: - Scan Confirm Sheet

/// Shown after a valid RxNorm-confirmed scan. One tap saves directly to the database.
struct ScanConfirmSheet: View {
    let scan: ScannedMedication
    let patientId: Int
    let onSuccess: () -> Void
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Scanned Medication")) {
                    LabeledContent("Name", value: scan.canonicalName ?? scan.name ?? "—")
                    if let dosage = scan.dosage {
                        LabeledContent("Dosage", value: dosage)
                    }
                    if let frequency = scan.frequency {
                        LabeledContent("Frequency", value: frequency)
                    }
                    if let instructions = scan.instructions {
                        LabeledContent("Instructions", value: instructions)
                    }
                }

                if scan.rxcui != nil {
                    Section {
                        Label("Verified in RxNorm database", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Color.cbGreen)
                            .font(.subheadline)
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Add Medication").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Confirm Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard let token = authManager.token else { return }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await APIService.shared.addMedication(
                patientId: patientId,
                name: (scan.canonicalName ?? scan.name ?? "").trimmingCharacters(in: .whitespaces),
                dosage: scan.dosage?.trimmingCharacters(in: .whitespaces) ?? "",
                frequency: scan.frequency?.trimmingCharacters(in: .whitespaces) ?? "",
                instructions: scan.instructions?.trimmingCharacters(in: .whitespaces),
                token: token
            )
            onSuccess()
            dismiss()
        } catch {
            errorMessage = "Failed to save medication. Please try again."
        }
        isSaving = false
    }
}
