import Foundation
import CoreGraphics

struct PillCandidate {
    let boundingBox: CGRect
    let imprint: String?
    let shape: String
    let color: String
    let confidence: Double
}
