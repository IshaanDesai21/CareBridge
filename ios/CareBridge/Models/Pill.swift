struct Pill: Codable, Identifiable {
    let id: String
    let name: String
    let rxcui: Int
    let imprint: String
    let shape: String
    let color: String
}
