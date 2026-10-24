import Vision
import UIKit

struct PillDetectionResult {
    let candidates: [PillCandidate]
    /// Number of distinct physical pills detected (clusters of text observations).
    let pillCount: Int
}

final class PillDetectionService {

    func detectPills(image: UIImage) async -> PillDetectionResult {
        guard let cgImage = image.cgImage else { return PillDetectionResult(candidates: [], pillCount: 0) }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: PillDetectionResult(candidates: [], pillCount: 0))
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

                let pillCount = Self.countPillClusters(candidates: candidates)
                continuation.resume(returning: PillDetectionResult(candidates: candidates, pillCount: pillCount))
            }

            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: PillDetectionResult(candidates: [], pillCount: 0))
            }
        }
    }

    // Groups overlapping / nearby text observations into pill clusters.
    // Two observations belong to the same pill when their bounding-box centres
    // are within `threshold` units of each other in normalised VN coordinates.
    private static func countPillClusters(candidates: [PillCandidate], threshold: Double = 0.12) -> Int {
        guard !candidates.isEmpty else { return 0 }
        var visited = Set<Int>()
        var count = 0
        for i in candidates.indices {
            guard !visited.contains(i) else { continue }
            count += 1
            visited.insert(i)
            let a = candidates[i].boundingBox
            let ax = a.midX, ay = a.midY
            for j in candidates.indices where j > i && !visited.contains(j) {
                let b = candidates[j].boundingBox
                let dist = hypot(ax - b.midX, ay - b.midY)
                if dist < threshold { visited.insert(j) }
            }
        }
        return count
    }
}
