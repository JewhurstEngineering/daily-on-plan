import SwiftUI
import SwiftData
import Charts

enum OnPlanKeyboard {
    case `default`
    case decimalPad
    case numberPad
}

extension Color {
    static var onPlanSecondaryFill: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var onPlanTertiaryFill: Color {
        #if os(iOS)
        Color(.tertiarySystemFill)
        #else
        Color(nsColor: .tertiarySystemFill)
        #endif
    }
}

extension View {
    @ViewBuilder
    func onPlanInlineNav() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func onPlanKeyboard(_ kind: OnPlanKeyboard) -> some View {
        #if os(iOS)
        switch kind {
        case .default: keyboardType(.default)
        case .decimalPad: keyboardType(.decimalPad)
        case .numberPad: keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func onPlanNeverAutocapitalize() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func onPlanKeyboardDone(_ action: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { action() }
            }
        }
        #else
        self
        #endif
    }
}

extension ModelContext {
    func saveAndNotifyJournal() {
        try? save()
        NotificationCenter.default.post(name: .onPlanJournalDidChange, object: nil)
    }
}

extension View {
    /// Pins the Y axis around logged values and an optional goal, instead of stretching to zero.
    func chartPaddedYScale(
        values: [Double],
        goal: Double? = nil,
        pad: Double,
        floorAtZero: Bool = false
    ) -> some View {
        modifier(
            ChartPaddedYScaleModifier(
                values: values,
                goal: goal,
                pad: pad,
                floorAtZero: floorAtZero
            )
        )
    }
}

private struct ChartPaddedYScaleModifier: ViewModifier {
    let values: [Double]
    let goal: Double?
    let pad: Double
    let floorAtZero: Bool

    func body(content: Content) -> some View {
        if let domain = ChartValueScale.domain(
            values: values,
            goal: goal,
            pad: pad,
            floorAtZero: floorAtZero
        ) {
            content.chartYScale(domain: domain)
        } else {
            content
        }
    }
}
