import SwiftUI
import UIKit

struct PillVerificationView: View {
    let patientId: Int
    let medications: [Medication]
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var capturedImage: UIImage? = nil
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult? = nil
    @State private var showCamera = false

    enum VerificationResult {
        case match([Pill])
        case mismatch(unexpected: [Pill], expected: [String])
        case unrecognized
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isVerifying {
                    ProgressView("Checking pills…")
                        .accessibilityLabel("Verifying pill identity")
                } else if let result = verificationResult {
                    resultView(for: result)
                } else {
                    instructionView
                }
            }
            .padding()
            .navigationTitle("Verify Pills")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCamera = false
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                capturedImage = image
                showCamera = false
                Task { await verify(image: image) }
            }
        }
        .onAppear { showCamera = true }
    }

    private var instructionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Take a photo of the pills to verify them against the prescription.")
                .multilineTextAlignment(.center)
            Button("Open Camera") { showCamera = true }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func resultView(for result: VerificationResult) -> some View {
        switch result {
        case .match(let pills):
            PillMatchView(pills: pills) { reset() }
        case .mismatch(let unexpected, let expected):
            PillMismatchView(unexpected: unexpected, expected: expected) { reset() }
        case .unrecognized:
            PillUnrecognizedView { reset() }
        }
    }

    private func reset() {
        capturedImage = nil
        verificationResult = nil
        showCamera = true
    }

    @MainActor
    private func verify(image: UIImage) async {
        isVerifying = true
        let service = PillDetectionService()
        let candidates = await service.detectPills(image: image)
        let index = PillImprintIndex()
        let detected = candidates.compactMap { c -> Pill? in
            guard let imp = c.imprint else { return nil }
            return index.lookup(imprint: imp)
        }
        let expectedNames = Set(medications.map { $0.name.lowercased() })
        let unexpected = detected.filter { !expectedNames.contains($0.name.lowercased()) }
        if detected.isEmpty {
            verificationResult = .unrecognized
        } else if unexpected.isEmpty {
            verificationResult = .match(detected)
        } else {
            verificationResult = .mismatch(unexpected: unexpected, expected: medications.map { $0.name })
        }

        // Log verification result to backend audit trail (text only — no images leave device)
        if let firstMed = medications.first, let token = authManager.token {
            let status: String? = switch verificationResult {
                case .match: "match"
                case .mismatch: "mismatch"
                case .unrecognized, .none: nil
            }
            if let status {
                let pillsPayload = detected.map { ["name": $0.name, "imprint": $0.imprint] }
                try? await APIService.shared.logVerification(
                    medicationId: firstMed.id,
                    status: status,
                    pills: pillsPayload,
                    token: token
                )
            }
        }

        isVerifying = false
    }
}

// MARK: - Sub-views

struct PillMatchView: View {
    let pills: [Pill]
    let onRetake: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60)).foregroundStyle(.green)
                .accessibilityLabel("Verification passed")
            Text("All pills verified").font(.title2).bold()
            Text(pills.map { $0.name }.joined(separator: ", "))
                .foregroundStyle(.secondary)
            Button("Done") { onRetake() }.buttonStyle(.borderedProminent)
        }
    }
}

struct PillMismatchView: View {
    let unexpected: [Pill]
    let expected: [String]
    let onRetake: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60)).foregroundStyle(.orange)
                .accessibilityLabel("Verification warning")
            Text("Medication mismatch").font(.title2).bold()
            Text("Detected: \(unexpected.map { $0.name }.joined(separator: ", "))")
                .foregroundStyle(.red)
            Text("Expected: \(expected.joined(separator: ", "))")
                .foregroundStyle(.secondary)
            Button("Retake Photo") { onRetake() }.buttonStyle(.borderedProminent)
            Button("Ignore Warning") { onRetake() }.foregroundStyle(.secondary)
        }
    }
}

struct PillUnrecognizedView: View {
    let onRetake: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60)).foregroundStyle(.secondary)
                .accessibilityLabel("No pills recognized")
            Text("No pills recognized").font(.title2).bold()
            Text("Make sure imprints are visible and well-lit.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try Again") { onRetake() }.buttonStyle(.borderedProminent)
        }
    }
}
