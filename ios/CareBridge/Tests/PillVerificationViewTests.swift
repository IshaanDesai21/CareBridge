import XCTest
@testable import CareBridge

final class PillVerificationViewTests: XCTestCase {

    // MARK: - Helpers

    private func makePill(id: String = "1", name: String = "Metformin", rxcui: Int = 0) -> Pill {
        Pill(id: id, name: name, rxcui: rxcui, imprint: "M500", shape: "round", color: "white")
    }

    // MARK: - Tests

    func testVerificationResultMatchEnumCase() {
        let pill = makePill()
        let result = PillVerificationView.VerificationResult.match([pill])
        if case .match(let pills) = result {
            XCTAssertEqual(pills.count, 1)
            XCTAssertEqual(pills.first?.name, "Metformin")
        } else {
            XCTFail("Expected .match case")
        }
    }

    func testVerificationResultMismatchEnumCase() {
        let pill = makePill(name: "Ibuprofen")
        let result = PillVerificationView.VerificationResult.mismatch(unexpected: [pill], expected: ["Other"])
        if case .mismatch(let unexpected, let expected) = result {
            XCTAssertEqual(unexpected.count, 1)
            XCTAssertEqual(unexpected.first?.name, "Ibuprofen")
            XCTAssertEqual(expected, ["Other"])
        } else {
            XCTFail("Expected .mismatch case")
        }
    }

    func testVerificationResultUnrecognizedEnumCase() {
        let result = PillVerificationView.VerificationResult.unrecognized
        if case .unrecognized = result {
            // Pass — correct enum case
        } else {
            XCTFail("Expected .unrecognized case")
        }
    }
}
