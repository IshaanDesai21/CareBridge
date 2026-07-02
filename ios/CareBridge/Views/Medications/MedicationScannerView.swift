import SwiftUI
import VisionKit

/// Live camera text scanner for medication labels. Recognizes text
/// automatically as the camera holds steady on a label — no shutter button —
/// and reports the combined transcript once it's held stable for a moment.
struct MedicationScannerView: UIViewControllerRepresentable {
    var onStableText: (String) -> Void

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
        private var stableFrameCount = 0
        private var hasFired = false

        init(onStableText: @escaping (String) -> Void) {
            self.onStableText = onStableText
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdateRecognizedItems allItems: [RecognizedItem]) {
            guard !hasFired else { return }

            let combined = allItems.compactMap { item -> String? in
                if case .text(let text) = item { return text.transcript }
                return nil
            }.joined(separator: "\n")

            // Require a reasonable amount of legible text before treating it as a candidate.
            guard combined.count > 8 else {
                stableFrameCount = 0
                lastText = combined
                return
            }

            if combined == lastText {
                stableFrameCount += 1
            } else {
                stableFrameCount = 0
                lastText = combined
            }

            // The same text held across several consecutive frames means the
            // camera is steady and the recognizer has locked on — auto-capture.
            if stableFrameCount >= 6 {
                hasFired = true
                onStableText(combined)
            }
        }
    }
}

/// Wraps the scanner with permission/availability handling and a status overlay.
struct MedicationScannerScreen: View {
    var onCaptured: (String) -> Void
    var onCancel: () -> Void

    @State private var isSupported = DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    @State private var cameraAuthorized = false
    @State private var checkedAuthorization = false

    var body: some View {
        ZStack {
            if !isSupported {
                unsupportedView
            } else if checkedAuthorization && !cameraAuthorized {
                deniedView
            } else if checkedAuthorization {
                MedicationScannerView(onStableText: onCaptured)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        Text("Hold steady over the label…")
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
