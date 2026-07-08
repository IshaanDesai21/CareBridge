import Vision
import UIKit

final class PillDetectionService {

    func detectPills(image: UIImage) async -> [PillCandidate] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let candidates: [PillCandidate] = observations.compactMap { observation in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }

                    let transcript = topCandidate.string.trimmingCharacters(in: .whitespaces)
                    guard transcript.count >= 2 else { return nil }

                    return PillCandidate(
                        boundingBox: observation.boundingBox,
                        imprint: transcript.uppercased(),
                        shape: "unknown",
                        color: "unknown",
                        confidence: Double(topCandidate.confidence)
                    )
                }

                continuation.resume(returning: candidates)
            }

            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}
