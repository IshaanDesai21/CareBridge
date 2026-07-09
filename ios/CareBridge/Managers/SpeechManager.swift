import Foundation
import Speech
import AVFoundation

/// Live speech-to-text for the AI companion chat's voice input button.
/// Wraps SFSpeechRecognizer + AVAudioEngine and publishes the transcript as
/// the user speaks, so the text field updates in real time.
final class SpeechManager: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioApplication.requestRecordPermission { micGranted in
                DispatchQueue.main.async {
                    completion(status == .authorized && micGranted)
                }
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            return
        }

        errorMessage = nil
        transcript = ""

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't access the microphone."
            resetAudio()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // AVAudioEngine raises an *Objective-C* exception (→ SIGABRT, uncatchable
        // by Swift's do/catch) if the tap format is invalid. That happens when no
        // real input route is available — the Simulator, another app holding the
        // mic, or a mid-session route change — where the format comes back with a
        // 0 sample rate / 0 channels. Guard against it, then still run the tap
        // install + engine start through an Objective-C @try/@catch so any
        // remaining framework exception surfaces as a handled error, never a crash.
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            errorMessage = "The microphone isn't available on this device right now."
            resetAudio()
            return
        }

        do {
            try ObjC.catchException { [weak self] in
                guard let self else { return }
                inputNode.removeTap(onBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                    self?.request?.append(buffer)
                }
                self.audioEngine.prepare()
            }
            try audioEngine.start()
        } catch {
            errorMessage = "Couldn't start audio recording."
            resetAudio()
            return
        }

        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async { self.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
    }

    /// Tears the audio graph back down to a clean state after any failed start,
    /// so a later attempt doesn't inherit a half-configured engine (a stuck tap
    /// or active session is itself a source of the next abort).
    private func resetAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        try? ObjC.catchException {
            self.audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if audioEngine.isRunning { audioEngine.stop() }
        try? ObjC.catchException {
            self.audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
