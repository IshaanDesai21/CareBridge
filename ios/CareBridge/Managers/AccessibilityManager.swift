import SwiftUI
import UIKit
import Combine

/// Reads the accessibility preferences stored under the `a11y_*` UserDefaults
/// keys (set from `AccessibilitySettingsView`) and turns them into real,
/// observable effects: Dynamic Type scaling, bold text, contrast, motion,
/// haptics, and VoiceOver hints — applied app-wide from `CareBridgeApp`.
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published private(set) var largeText: Bool
    @Published private(set) var highContrast: Bool
    @Published private(set) var boldText: Bool
    @Published private(set) var reduceMotionSetting: Bool
    @Published private(set) var voiceOverHints: Bool
    @Published private(set) var haptics: Bool

    private var cancellable: AnyCancellable?
    private let defaults = UserDefaults.standard

    private init() {
        largeText = defaults.bool(forKey: "a11y_largeText")
        highContrast = defaults.bool(forKey: "a11y_highContrast")
        boldText = defaults.bool(forKey: "a11y_boldText")
        reduceMotionSetting = defaults.bool(forKey: "a11y_reduceMotion")
        voiceOverHints = defaults.object(forKey: "a11y_voiceOverHints") == nil ? true : defaults.bool(forKey: "a11y_voiceOverHints")
        haptics = defaults.object(forKey: "a11y_haptics") == nil ? true : defaults.bool(forKey: "a11y_haptics")

        // @AppStorage in the settings screen writes straight to UserDefaults.standard;
        // this keeps every other screen's copy of these flags in sync in real time.
        cancellable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        let newLargeText = defaults.bool(forKey: "a11y_largeText")
        let newHighContrast = defaults.bool(forKey: "a11y_highContrast")
        let newBoldText = defaults.bool(forKey: "a11y_boldText")
        let newReduceMotion = defaults.bool(forKey: "a11y_reduceMotion")
        let newVoiceOverHints = defaults.object(forKey: "a11y_voiceOverHints") == nil ? true : defaults.bool(forKey: "a11y_voiceOverHints")
        let newHaptics = defaults.object(forKey: "a11y_haptics") == nil ? true : defaults.bool(forKey: "a11y_haptics")

        if newLargeText != largeText { largeText = newLargeText }
        if newHighContrast != highContrast { highContrast = newHighContrast }
        if newBoldText != boldText { boldText = newBoldText }
        if newReduceMotion != reduceMotionSetting { reduceMotionSetting = newReduceMotion }
        if newVoiceOverHints != voiceOverHints { voiceOverHints = newVoiceOverHints }
        if newHaptics != haptics { haptics = newHaptics }
    }

    /// Combines the in-app toggle with the system-level "Reduce Motion" setting —
    /// either one should be enough to disable non-essential animation.
    var reduceMotion: Bool { reduceMotionSetting || UIAccessibility.isReduceMotionEnabled }

    var legibilityWeight: LegibilityWeight? { boldText ? .bold : nil }

    /// A subtle but real contrast boost — darkens borders/secondary text against
    /// the background when "High Contrast" is enabled.
    var contrastAmount: Double { highContrast ? 1.18 : 1.0 }
    var saturationAmount: Double { highContrast ? 1.08 : 1.0 }

    func animation(_ base: Animation = .default) -> Animation? {
        reduceMotion ? nil : base
    }

    func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    /// Returns the hint text only when VoiceOver hints are enabled, so callers
    /// can write `.accessibilityHint(manager.hint("..."))` unconditionally.
    func hint(_ text: String) -> String {
        voiceOverHints ? text : ""
    }
}

// MARK: - Root accessibility modifier

private struct AccessibleRootModifier: ViewModifier {
    @ObservedObject var manager: AccessibilityManager

    func body(content: Content) -> some View {
        Group {
            if manager.largeText {
                content.dynamicTypeSize(DynamicTypeSize.xLarge ... DynamicTypeSize.accessibility5)
            } else {
                content
            }
        }
        .environment(\.legibilityWeight, manager.legibilityWeight)
        .contrast(manager.contrastAmount)
        .saturation(manager.saturationAmount)
    }
}

extension View {
    /// Applies every `AccessibilityManager` preference (Dynamic Type range,
    /// bold text, contrast) to this view's subtree. Apply once at the app root.
    func accessibleRoot() -> some View {
        modifier(AccessibleRootModifier(manager: .shared))
    }
}
