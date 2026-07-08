import XCTest

// NOTE: Full detection tests (e.g. asserting non-empty results from a real pill image)
// require a physical device or Xcode simulator with a bundled test image asset.
// The stubs below cover crash-safety and struct construction without a simulator.

final class PillDetectionServiceTests: XCTestCase {

    func testDetectPillsWithNilImage() async {
        // Create a minimal 1x1 white UIImage — cgImage will be valid,
        // but OCR should return zero candidates (no legible text).
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        let service = PillDetectionService()
        let results = await service.detectPills(image: image)
        // Must not crash; result is a valid array (likely empty for a blank image).
        XCTAssertNotNil(results)
    }

    func testPillCandidateHasRequiredFields() {
        let box = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.15)
        let candidate = PillCandidate(
            boundingBox: box,
            imprint: "M523",
            shape: "round",
            color: "white",
            confidence: 0.92
        )

        XCTAssertEqual(candidate.boundingBox, box)
        XCTAssertEqual(candidate.imprint, "M523")
        XCTAssertEqual(candidate.shape, "round")
        XCTAssertEqual(candidate.color, "white")
        XCTAssertEqual(candidate.confidence, 0.92, accuracy: 1e-9)
    }
}
