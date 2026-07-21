import SwiftUI
import SwiftData

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

    private var collapsed: Bool {
        isCollapsed?.wrappedValue ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(emphasis == .caution ? Color.orange : Color.accentColor)
                }
                Text(title)
                    .font(.headline)
                if emphasis == .caution {
                    Text("Over")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 8)
                trailing()
                if let isCollapsed {
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

            if collapsed {
                Text(collapsedMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                content
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(emphasis == .caution ? Color.orange.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            var tip = Path(roundedRect: CGRect(x: w * 0.04, y: cigY, width: tipWidth, height: cigHeight), cornerRadius: cigHeight / 2)
            context.fill(tip, with: .color(.secondary.opacity(0.55)))

            // Paper body
            var paper = Path(roundedRect: CGRect(x: w * 0.04 + tipWidth, y: cigY, width: bodyWidth, height: cigHeight), cornerRadius: 1)
            context.fill(paper, with: .color(.primary.opacity(0.85)))

            // Filter
            var filter = Path(roundedRect: CGRect(x: w * 0.04 + tipWidth + bodyWidth, y: cigY, width: filterWidth, height: cigHeight), cornerRadius: cigHeight / 3)
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

struct CalorieRingView: View {
    let current: Int
    let goal: Int
    @Environment(\.accentTheme) private var theme

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.2)
    }

    private var isOver: Bool { current > goal }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(
                    isOver ? theme.warning : theme.progress,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: current)
            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.title2.bold().monospacedDigit())
                Text("/ \(goal) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 110, height: 110)
    }
}

struct GlassButton: View {
    let isFilled: Bool
    let label: String
    let action: () -> Void
    @Environment(\.accentTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isFilled ? "waterbottle.fill" : "waterbottle")
                    .font(.title3)
                    .foregroundStyle(isFilled ? theme.progress : Color.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isFilled ? theme.progress.opacity(0.12) : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SuggestionChipRow: View {
    let items: [SuggestionItem]
    let onTap: (SuggestionItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct MultiplierPicker: View {
    @Binding var multiplier: Double
    var options: [Double] = [1, 2, 3, 4, 5, 6]
    var onSelect: ((Double) -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { value in
                let selected = abs(multiplier - value) < 0.01
                Button {
                    multiplier = value
                    onSelect?(value)
                } label: {
                    Text("\(Int(value))×")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Color.accentColor : Color(.tertiarySystemFill))
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
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
