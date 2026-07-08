final class PillImprintIndex {
    private var index: [String: Pill] = [:]

    init() { loadIndex() }

    private func loadIndex() {
        guard let url = Bundle.main.url(forResource: "pill_index", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        let pills = (try? JSONDecoder().decode([Pill].self, from: data)) ?? []
        pills.forEach { index[$0.imprint.uppercased()] = $0 }
    }

    func lookup(imprint: String) -> Pill? {
        index[imprint.uppercased()]
    }
}
