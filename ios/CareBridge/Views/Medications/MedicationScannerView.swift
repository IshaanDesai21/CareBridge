import SwiftUI
import VisionKit

/// Bridges a SwiftUI button tap into the live-updating UIKit coordinator below,
/// since UIViewControllerRepresentable has no built-in way for its parent view
/// to directly invoke a method on the coordinator it doesn't own a reference to.
final class ScannerCaptureTrigger: ObservableObject {
    fileprivate var captureAction: (() -> Void)?
    /// True once at least one recognizable line of text is on screen, so the
    /// capture button can tell the user when there's actually something to grab.
    @Published var hasRecognizableText = false

    func capture() { captureAction?() }
}

/// Live camera text scanner for medication labels. Recognizes text as the
/// camera holds it in frame; the user explicitly taps "Capture" (driven by
/// `ScannerCaptureTrigger`) to accept whatever is currently recognized rather
/// than relying on an automatic stability heuristic.
struct MedicationScannerView: UIViewControllerRepresentable {
    var onStableText: (String) -> Void
    var trigger: ScannerCaptureTrigger

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        context.coordinator.trigger = trigger
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onStableText: onStableText) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onStableText: (String) -> Void
        private var lastText = ""
        private var hasFired = false
        weak var trigger: ScannerCaptureTrigger? {
            didSet { trigger?.captureAction = { [weak self] in self?.captureCurrentText() } }
        }

        init(onStableText: @escaping (String) -> Void) {
            self.onStableText = onStableText
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdateRecognizedItems allItems: [RecognizedItem]) {
            guard !hasFired else { return }

            let combined = allItems.compactMap { item -> String? in
                if case .text(let text) = item { return text.transcript }
                return nil
            }.joined(separator: "\n")

            lastText = combined
            let ready = combined.count > 8
            if trigger?.hasRecognizableText != ready {
                DispatchQueue.main.async { self.trigger?.hasRecognizableText = ready }
            }
        }

        /// Fires with whatever text is currently in frame, however much or little
        /// that is — the user decided it's ready, not a stability heuristic.
        func captureCurrentText() {
            guard !hasFired else { return }
            let text = lastText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            hasFired = true
            onStableText(text)
        }
    }
}

/// Wraps the scanner with permission/availability handling and a manual
/// "Capture" button — the user reviews the label in frame and taps when ready,
/// rather than the camera auto-firing once text looks stable.
struct MedicationScannerScreen: View {
    var onCaptured: (String) -> Void
    var onCancel: () -> Void

    @State private var isSupported = DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    @State private var cameraAuthorized = false
    @State private var checkedAuthorization = false
    @StateObject private var captureTrigger = ScannerCaptureTrigger()

    var body: some View {
        ZStack {
            if !isSupported {
                unsupportedView
            } else if checkedAuthorization && !cameraAuthorized {
                deniedView
            } else if checkedAuthorization {
                MedicationScannerView(onStableText: onCaptured, trigger: captureTrigger)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        Text(captureTrigger.hasRecognizableText ? "Text found — tap Capture when ready" : "Point the camera at the label…")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(.top, 60)
                    }
                    .overlay(alignment: .topTrailing) {
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding()
                    }
                    .overlay(alignment: .bottom) {
                        Button {
                            captureTrigger.capture()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("Capture")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(captureTrigger.hasRecognizableText ? Color.cbPrimary : Color.gray)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(!captureTrigger.hasRecognizableText)
                        .padding(.bottom, 48)
                    }
            } else {
                ProgressView().onAppear { checkAuthorization() }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func checkAuthorization() {
        switch AVCaptureDeviceAuthorizationStatus() {
        case .authorized:
            cameraAuthorized = true
            checkedAuthorization = true
        default:
            AVCaptureDeviceRequestAccess { granted in
                DispatchQueue.main.async {
                    cameraAuthorized = granted
                    checkedAuthorization = true
                }
            }
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44)).foregroundStyle(.white)
            Text("Live scanning isn't supported on this device.")
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Text("Enter the medication details manually instead.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.7))
            Button("Close", action: onCancel)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 44)).foregroundStyle(.white)
            Text("Camera access is needed to scan a label.")
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Close", action: onCancel)
        }
        .padding(32)
    }
}

// MARK: - Small AVFoundation auth helper (kept local to avoid an extra import site)

import AVFoundation

private func AVCaptureDeviceAuthorizationStatus() -> AVAuthorizationStatus {
    AVCaptureDevice.authorizationStatus(for: .video)
}

private func AVCaptureDeviceRequestAccess(completion: @escaping (Bool) -> Void) {
    AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
}
