import XCTest

// NOTE: These tests require an Xcode simulator to pass.
// When run outside Xcode, Bundle.main.url(forResource:) returns nil,
// so the index will be empty and lookup calls return nil.
// The assertions below document the intended behavior and will pass
// once pill_index.json is bundled and loaded in the simulator.

final class PillImprintIndexTests: XCTestCase {

    func testLookupKnownImprint() {
        // Requires simulator: Bundle.main must resolve pill_index.json
        let index = PillImprintIndex()
        let pill = index.lookup(imprint: "M523")
        XCTAssertNotNil(pill)
        XCTAssertEqual(pill?.name, "Metformin")
        XCTAssertEqual(pill?.rxcui, 6809)
    }

    func testLookupCaseInsensitive() {
        // Lowercase imprint should resolve to the same pill
        let index = PillImprintIndex()
        let pill = index.lookup(imprint: "m523")
        XCTAssertNotNil(pill)
    }

    func testLookupUnknownImprint() {
        let index = PillImprintIndex()
        let pill = index.lookup(imprint: "NOTAREALPILL")
        XCTAssertNil(pill)
    }
}
