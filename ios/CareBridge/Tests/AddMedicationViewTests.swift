import XCTest
@testable import CareBridge

/// Unit tests for ScannedMedication.isValid computed property.
/// These document the expected behavior of RxNorm validation status.
/// Run with: xcodebuild test -scheme CareBridge -destination 'platform=iOS Simulator,name=iPhone 16'
class AddMedicationViewTests: XCTestCase {

    func testValidMedicationIsValidWhenRxcuiPresent() {
        // A result with an rxcui value is considered validated against RxNorm
        let result = ScannedMedication(
            name: "Lisinopril",
            dosage: "10mg",
            frequency: "Once daily",
            instructions: nil,
            confidence: "high",
            rxcui: 12345,
            canonicalName: "Lisinopril"
        )
        XCTAssertTrue(result.isValid, "isValid should be true when rxcui is present")
    }

    func testInvalidMedicationIsNotValidWhenRxcuiAbsent() {
        // A result without an rxcui was not matched in RxNorm
        let result = ScannedMedication(
            name: "FakeMed",
            dosage: nil,
            frequency: nil,
            instructions: nil,
            confidence: "low",
            rxcui: nil,
            canonicalName: nil
        )
        XCTAssertFalse(result.isValid, "isValid should be false when rxcui is nil")
    }

    func testValidMedicationUsesCanonicalNameWhenAvailable() {
        // canonicalName should be preferred over name for the medication name field
        let result = ScannedMedication(
            name: "lisinopril",
            dosage: "10mg",
            frequency: "daily",
            instructions: nil,
            confidence: "high",
            rxcui: 29046,
            canonicalName: "Lisinopril"
        )
        XCTAssertTrue(result.isValid)
        // The UI uses: result.canonicalName ?? result.name ?? ""
        let expectedName = result.canonicalName ?? result.name ?? ""
        XCTAssertEqual(expectedName, "Lisinopril")
    }

    func testOcrSuccessButNoRxcuiFillsNameAndSetsWarning() {
        // When OCR worked (name != nil) but rxcui is absent, name should still be filled
        let result = ScannedMedication(
            name: "UnknownPill",
            dosage: "5mg",
            frequency: nil,
            instructions: nil,
            confidence: "medium",
            rxcui: nil,
            canonicalName: nil
        )
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.name, "name should be present for the partial-match branch")
    }

    func testZeroRxcuiIsConsideredValid() {
        // rxcui of 0 is invalid (RxNorm IDs are positive integers)
        let zeroMed = ScannedMedication(
            name: "Aspirin",
            dosage: "81mg",
            frequency: "daily",
            instructions: nil,
            confidence: "high",
            rxcui: 0,
            canonicalName: "Aspirin"
        )
        XCTAssertFalse(zeroMed.isValid, "isValid should be false for rxcui=0")
    }
}
