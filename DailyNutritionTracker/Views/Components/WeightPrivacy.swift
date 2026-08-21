import SwiftUI
import OnPlanCore

/// Session-scoped reveal for the masked weight figure.
///
/// Deliberately never persisted: leaving the app re-hides, so a revealed weight is never
/// left sitting on screen. The preference that turns masking on at all is
/// `DisplayPreferences.hideWeightUntilTapped`; this type only tracks "has the viewer
/// tapped to reveal, right now".
@MainActor
final class WeightRevealState: ObservableObject {
    @Published private(set) var isRevealed = false

    func reveal() {
        guard !isRevealed else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isRevealed = true
        }
    }

    /// Hide again on demand — the eye button on the weight card, or its long-press menu.
    /// Also called when the app leaves the foreground.
    func hide() {
        guard isRevealed else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isRevealed = false
        }
    }
}

/// Whether weight figures should currently be masked, resolved from the stored preference
/// and the session reveal together. Read this rather than either half on its own.
@MainActor
struct WeightMasking {
    let isMasked: Bool
    /// True when masking is switched on but the viewer has revealed it for now — the only
    /// state where a "hide again" affordance makes sense.
    let canHide: Bool
    let reveal: @MainActor () -> Void
    let hide: @MainActor () -> Void

    init(preferences: DisplayPreferences, state: WeightRevealState) {
        let enabled = preferences.hideWeightUntilTapped
        isMasked = enabled && !state.isRevealed
        canHide = enabled && state.isRevealed
        reveal = { [weak state] in state?.reveal() }
        hide = { [weak state] in state?.hide() }
    }
}

/// Replaces a sensitive figure with fixed-width dots while keeping the real value's
/// footprint, so revealing never reflows the surrounding layout.
///
/// The threat model is a glance over your shoulder, not a determined attacker with the
/// device — the value is laid out but not painted, and is hidden from accessibility.
struct PrivateFigure<Value: View>: View {
    var isMasked: Bool
    var dotCount: Int = 4
    var dotSize: CGFloat = 11
    var accessibilityLabelWhenMasked: String = "Hidden. Double tap to show."
    @ViewBuilder var value: Value

    var body: some View {
        ZStack(alignment: .leading) {
            value
                .opacity(isMasked ? 0 : 1)
                .accessibilityHidden(isMasked)

            if isMasked {
                HStack(spacing: dotSize * 0.64) {
                    ForEach(0..<dotCount, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.55))
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabelWhenMasked)
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}

extension View {
    /// Re-hides revealed weight whenever the app leaves the foreground.
    func rehidesWeightOnBackground(_ state: WeightRevealState, phase: ScenePhase) -> some View {
        onChange(of: phase) { _, newPhase in
            if newPhase != .active {
                state.hide()
            }
        }
    }
}
