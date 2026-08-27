import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

extension WaterSlotRecord {
    /// SF Symbol that is guaranteed to exist on the running OS (avoids blank icons).
    var resolvedSystemImage: String {
        #if canImport(UIKit)
        if UIImage(systemName: systemImage) != nil {
            return systemImage
        }
        #endif
        switch kind {
        case .water, .electrolyte:
            return "waterbottle.fill"
        case .other:
            return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

/// The shared card chrome (padding, background, corner radius, optional caution border) used by
/// every `SectionCard` and, via this type directly, by non-collapsible cards like Reports screens —
/// see docs/DESIGN_IMPROVEMENT_PLAN.md §5.2. Reports previously re-implemented this same recipe inline.
struct Card<Content: View>: View {
    var emphasis: SectionCardEmphasis = .none
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(emphasis == .caution ? Color.orange.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .animation(.easeInOut(duration: 0.25), value: emphasis)
    }

    private var cardBackground: Color {
        switch emphasis {
        case .none:
            return Color(.secondarySystemGroupedBackground)
        case .caution:
            return Color.orange.opacity(0.10)
        }
    }
}

struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    var isCollapsed: Binding<Bool>? = nil
    var collapsedMessage: String = "Collapsed — tap the chevron to show."
    var emphasis: SectionCardEmphasis = .none
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: Content

    init(
        title: String,
        systemImage: String? = nil,
        isCollapsed: Binding<Bool>? = nil,
        collapsedMessage: String = "Collapsed — tap the chevron to show.",
        emphasis: SectionCardEmphasis = .none,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isCollapsed = isCollapsed
        self.collapsedMessage = collapsedMessage
        self.emphasis = emphasis
        self.trailing = trailing
        self.content = content()
    }

    @Environment(\.sectionChrome) private var chrome

    private var collapsed: Bool {
        // A section that IS the screen has nothing to collapse into.
        guard chrome == .card else { return false }
        return isCollapsed?.wrappedValue ?? false
    }

    var body: some View {
        Card(emphasis: emphasis) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                // The nav bar already names a detail screen — no second title above the content.
                if chrome == .card {
                HStack(spacing: Spacing.s) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(emphasis == .caution ? Color.orange : Color.accentColor)
                    }
                    Text(title)
                        .font(.headline)
                    if emphasis == .caution {
                        Text("Over")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.18))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                    Spacer(minLength: 8)
                    trailing()
                    if let isCollapsed, chrome == .card {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCollapsed.wrappedValue.toggle()
                            }
                        } label: {
                            Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 36, minHeight: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(collapsed ? "Expand \(title)" : "Collapse \(title)")
                    }
                }
                }

                if collapsed {
                    Text(collapsedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    content
                }
            }
        }
    }
}

enum SectionCardEmphasis: Equatable {
    case none
    /// Soft over-limit highlight (smoking / drinking max).
    case caution
}

/// Big tap target for logging one habit unit (cig, drink) with a light bounce.
struct HabitTapButton<Icon: View>: View {
    let caption: String
    let isCaution: Bool
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon

    @State private var pressTick = 0

    init(
        caption: String,
        isCaution: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.caption = caption
        self.isCaution = isCaution
        self.accessibilityLabel = accessibilityLabel
        self.action = action
        self.icon = icon
    }

    var body: some View {
        Button {
            pressTick += 1
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill((isCaution ? Color.orange : Color.accentColor).opacity(0.14))
                    icon()
                        .foregroundStyle(isCaution ? Color.orange : Color.accentColor)
                }
                .frame(width: 68, height: 68)
                .symbolEffect(.bounce, value: pressTick)
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.impact(weight: .light), trigger: pressTick)
    }
}

/// Reliable cigarette glyph — `cigarette` SF Symbol is missing/blank on some installs.
struct CigaretteGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cigHeight = h * 0.22
            let cigY = (h - cigHeight) / 2
            let tipWidth = w * 0.18
            let filterWidth = w * 0.22
            let bodyWidth = w - tipWidth - filterWidth - w * 0.08

            // Ash / tip
            let tip = Path(roundedRect: CGRect(x: w * 0.04, y: cigY, width: tipWidth, height: cigHeight), cornerRadius: cigHeight / 2)
            context.fill(tip, with: .color(.secondary.opacity(0.55)))

            // Paper body
            let paper = Path(roundedRect: CGRect(x: w * 0.04 + tipWidth, y: cigY, width: bodyWidth, height: cigHeight), cornerRadius: 1)
            context.fill(paper, with: .color(.primary.opacity(0.85)))

            // Filter
            let filter = Path(roundedRect: CGRect(x: w * 0.04 + tipWidth + bodyWidth, y: cigY, width: filterWidth, height: cigHeight), cornerRadius: cigHeight / 3)
            context.fill(filter, with: .color(.orange.opacity(0.85)))

            // Little smoke wisp
            var wisp = Path()
            let sx = w * 0.08
            wisp.move(to: CGPoint(x: sx, y: cigY - 2))
            wisp.addCurve(
                to: CGPoint(x: sx - 4, y: cigY - h * 0.28),
                control1: CGPoint(x: sx + 6, y: cigY - h * 0.1),
                control2: CGPoint(x: sx - 10, y: cigY - h * 0.18)
            )
            context.stroke(wisp, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: 40, height: 40)
    }
}

struct GoalRingView: View {
    let current: Int
    let goal: Int
    var unit: String
    var treatOverAsWarning: Bool = false
    var successWhenMet: Bool = false
    /// Fractions of the full ring (0...1) for electrolyte highlights, drawn on top of the fill.
    var electrolyteSegments: [(start: Double, end: Double)] = []
    @Environment(\.appTheme) private var appTheme
    @Environment(\.accentProgress) private var progressColor

    /// Uncapped ratio used for overage arc (capped visually at +100% = two full loops).
    private var ratio: Double {
        guard goal > 0 else { return 0 }
        return Double(current) / Double(goal)
    }

    private var fillProgress: Double {
        min(max(ratio, 0), 1)
    }

    /// How far past 100% to draw in red, starting again at 12 o’clock (max one extra lap).
    private var overageProgress: Double {
        guard ratio > 1 else { return 0 }
        return min(ratio - 1, 1)
    }

    private var isOver: Bool { current > goal }
    private var isMet: Bool { goal > 0 && current >= goal }

    private var baseStrokeColor: Color {
        // Goal lap stays green when met/over; overage is drawn separately in red.
        if isMet { return appTheme.ok }
        return progressColor
    }

    private var overageColor: Color {
        Color.red.opacity(0.9)
    }

    private var electrolyteColor: Color {
        Color.yellow.opacity(0.95)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.onPlanHairline, lineWidth: 12)

            // Progress up to the goal (0 → 100%).
            Circle()
                .trim(from: 0, to: fillProgress)
                .stroke(
                    baseStrokeColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: current)

            // Overage past the goal wraps from 12 o’clock in red.
            if overageProgress > 0 {
                Circle()
                    .trim(from: 0, to: overageProgress)
                    .stroke(
                        overageColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: current)
            }

            ForEach(Array(visibleElectrolyteSegments.enumerated()), id: \.offset) { _, segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        electrolyteColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(isOver ? overageColor : .primary)
                Text("/ \(goal) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
        .accessibilityLabel(accessibilityText)
    }

    private var visibleElectrolyteSegments: [(start: Double, end: Double)] {
        let fillEnd = fillProgress
        return electrolyteSegments.compactMap { segment in
            let start = max(0, min(segment.start, fillEnd))
            let end = max(0, min(segment.end, fillEnd))
            // Keep a visible speck even for very small electrolyte pours.
            let paddedEnd = max(end, min(start + 0.035, fillEnd))
            guard paddedEnd > start else { return nil }
            return (start, paddedEnd)
        }
    }

    private var accessibilityText: String {
        var text = "\(current) of \(goal) \(unit)"
        if isOver {
            text += ", \(current - goal) over goal"
        }
        if !electrolyteSegments.isEmpty {
            text += ", includes electrolytes"
        }
        return text
    }
}

/// Maps filled water slots onto ring fractions (of the daily goal) for electrolyte highlights.
enum HydrationRingSegments {
    static func electrolyteSegments(slots: [WaterSlotRecord?], goalOz: Int) -> [(start: Double, end: Double)] {
        guard goalOz > 0 else { return [] }
        let goal = Double(goalOz)
        var cursor = 0.0
        var segments: [(start: Double, end: Double)] = []
        for slot in slots {
            guard let slot else { continue }
            let start = cursor / goal
            cursor += max(slot.oz, 0)
            let end = cursor / goal
            if slot.isElectrolyte {
                segments.append((start, end))
            }
        }
        return segments
    }
}

struct CalorieRingView: View {
    let current: Int
    let goal: Int

    var body: some View {
        GoalRingView(current: current, goal: goal, unit: "kcal", treatOverAsWarning: true)
    }
}

struct HydrationProgressBar: View {
    let current: Int
    let goal: Int
    var electrolyteSegments: [(start: Double, end: Double)] = []
    /// Off where the surrounding layout already states the total and goal — otherwise
    /// the same figures print twice, one above the other.
    var showsCaption: Bool = true
    @Environment(\.accentProgress) private var progressColor
    @Environment(\.appTheme) private var appTheme

    private var fraction: CGFloat {
        guard goal > 0 else { return 0 }
        return CGFloat(min(Double(current) / Double(goal), 1))
    }

    private var isMet: Bool { goal > 0 && current >= goal }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.onPlanHairline)
                    Capsule()
                        .fill(isMet ? appTheme.ok : progressColor)
                        .frame(width: max(8, geo.size.width * fraction))
                        .animation(.easeInOut(duration: 0.35), value: current)

                    ForEach(Array(visibleElectrolyteSegments.enumerated()), id: \.offset) { _, segment in
                        let width = max(6, geo.size.width * CGFloat(segment.end - segment.start))
                        Capsule()
                            .fill(Color.yellow.opacity(0.95))
                            .frame(width: width)
                            .offset(x: geo.size.width * CGFloat(segment.start))
                    }
                }
            }
            .frame(height: 12)

            if showsCaption {
            HStack {
                Text("\(current) / \(goal) oz")
                    .font(.caption.weight(.semibold).monospacedDigit())
                Spacer()
                if isMet {
                    Label("Goal hit", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appTheme.ok)
                } else {
                    Text("\(max(goal - current, 0)) oz to go")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydration \(current) of \(goal) ounces")
    }

    private var visibleElectrolyteSegments: [(start: Double, end: Double)] {
        let fillEnd = Double(fraction)
        return electrolyteSegments.compactMap { segment in
            let start = max(0, min(segment.start, fillEnd))
            let end = max(0, min(segment.end, fillEnd))
            let paddedEnd = max(end, min(start + 0.04, fillEnd))
            guard paddedEnd > start else { return nil }
            return (start, paddedEnd)
        }
    }
}

struct GlassButton: View {
    let isFilled: Bool
    var drinkKind: HydrationDrinkKind = .water
    var otherSubtype: HydrationOtherSubtype? = nil
    var isElectrolyte: Bool = false
    let label: String
    let action: () -> Void
    @Environment(\.accentProgress) private var progressColor

    private var resolvedKind: HydrationDrinkKind {
        if isElectrolyte { return .electrolyte }
        return drinkKind
    }

    private var resolvedRecord: WaterSlotRecord {
        WaterSlotRecord(
            oz: 1,
            kind: resolvedKind,
            otherSubtype: otherSubtype,
            isElectrolyte: isElectrolyte
        )
    }

    private var fillColor: Color {
        switch resolvedKind {
        case .water:
            return progressColor
        case .electrolyte:
            return Color.yellow.opacity(0.95)
        case .other:
            switch otherSubtype ?? .other {
            case .soda: return Color.pink.opacity(0.85)
            case .tea: return Color.green.opacity(0.75)
            case .coffee: return Color.brown.opacity(0.85)
            case .juice: return Color.orange.opacity(0.85)
            case .sparkling: return Color.cyan.opacity(0.8)
            case .milk: return Color.gray.opacity(0.7)
            case .other: return Color.secondary
            }
        }
    }

    private var iconName: String {
        isFilled ? resolvedRecord.resolvedSystemImage : "waterbottle"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(isFilled ? fillColor : Color.secondary)
                    if isFilled && resolvedRecord.showsElectrolyteBadge {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .offset(x: 6, y: -4)
                    }
                }
                .frame(height: 22)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isFilled ? fillColor.opacity(resolvedKind == .electrolyte ? 0.18 : 0.12) : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if !isFilled { return "Empty bottle, \(label)" }
        return "\(resolvedRecord.displayLabel) \(label)"
    }
}

/// Chip shape used by `chipStyle(...)` — capsule for toggled/selectable chips, rounded rect for
/// tap-to-act chips. See docs/DESIGN_IMPROVEMENT_PLAN.md §5.2 (one chip look, not three).
enum ChipShape {
    case capsule
    case roundedRect
}

/// Chip fill — one vocabulary for "selected" everywhere a chip appears, instead of each section
/// picking its own opacity/text-color combination. `.tinted` is the soft look (category pickers,
/// always-on suggestion chips); `.solid` is the high-contrast look (toggled reason chips).
enum ChipFill {
    case neutral
    case tinted(Color)
    case solid(Color)
}

/// Shared chip chrome (padding, fill, corner radius). Each call site keeps its own content layout
/// (icon, truncation, grid vs horizontal scroll) — only the visual "look" is unified here.
struct ChipStyleModifier: ViewModifier {
    var fill: ChipFill = .neutral
    var shape: ChipShape = .roundedRect
    var fullWidth: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(clipShape)
    }

    private var background: some ShapeStyle {
        switch fill {
        case .neutral: return AnyShapeStyle(Color(.secondarySystemBackground))
        case .tinted(let color): return AnyShapeStyle(color.opacity(0.18))
        case .solid(let color): return AnyShapeStyle(color)
        }
    }

    private var foreground: Color {
        switch fill {
        case .neutral: return .primary
        case .tinted(let color): return color
        case .solid: return .white
        }
    }

    private var clipShape: AnyShape {
        switch shape {
        case .capsule: AnyShape(Capsule())
        case .roundedRect: AnyShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
    }
}

extension View {
    func chipStyle(fill: ChipFill = .neutral, shape: ChipShape = .roundedRect, fullWidth: Bool = false) -> some View {
        modifier(ChipStyleModifier(fill: fill, shape: shape, fullWidth: fullWidth))
    }
}

struct SuggestionChipRow: View {
    let items: [SuggestionItem]
    let onTap: (SuggestionItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(items) { item in
                    Button {
                        onTap(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            if let subtitle = item.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .chipStyle(fill: .tinted(.accentColor))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension AppSettings {
    func sectionCollapsedBinding(_ section: DaySectionID, context: ModelContext) -> Binding<Bool> {
        Binding(
            get: { self.isSectionCollapsed(section) },
            set: {
                self.setSectionCollapsed(section, $0)
                try? context.save()
            }
        )
    }
}


/// How a `SectionCard` presents itself. On a pushed detail screen the navigation bar
/// already carries the title, and there is nothing above it to collapse into, so the
/// header row and chevron are dropped.
enum SectionChrome: Equatable {
    case card
    case detail
}

private struct SectionChromeKey: EnvironmentKey {
    static let defaultValue: SectionChrome = .card
}

extension EnvironmentValues {
    var sectionChrome: SectionChrome {
        get { self[SectionChromeKey.self] }
        set { self[SectionChromeKey.self] = newValue }
    }
}
