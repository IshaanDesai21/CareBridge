import Foundation

final class PillImprintIndex {
    private var index: [String: Pill] = [:]

    init() { loadIndex() }

    private func loadIndex() {
        guard let url = Bundle.main.url(forResource: "pill_index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        let pills = (try? JSONDecoder().decode([Pill].self, from: data)) ?? []
        pills.forEach { index[$0.imprint.uppercased()] = $0 }
    }

    /// Synchronous local lookup against the bundled index.
    func lookup(imprint: String) -> Pill? {
        index[imprint.uppercased()]
    }

    /// Remote lookup against the NIH C3PI / RxImage API, falling back to the
    /// bundled index when the network is unavailable or the pill isn't found.
    func lookupRemote(imprint: String, token: String) async -> Pill? {
        if let pill = try? await APIService.shared.lookupPill(imprint: imprint, token: token) {
            return pill
        }
        return lookup(imprint: imprint)
    }
}
