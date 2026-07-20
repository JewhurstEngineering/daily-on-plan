import SwiftUI

struct SectionCard<Content: View, Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: Content

    init(
        title: String,
        systemImage: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accentColor)
                }
                Text(title)
                    .font(.headline)
                Spacer()
                trailing()
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CalorieRingView: View {
    let current: Int
    let goal: Int

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
                .stroke(isOver ? Color.orange : Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isFilled ? "waterbottle.fill" : "waterbottle")
                    .font(.title3)
                    .foregroundStyle(isFilled ? Color.accentColor : Color.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isFilled ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Swipe left to reveal a Delete button (requires a second tap to confirm delete).
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    private let deleteWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer(minLength: 0)
                Button(role: .destructive) {
                    withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                    onDelete()
                } label: {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: deleteWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            content
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                offset = max(translation, -deleteWidth)
                            } else if offset < 0 {
                                offset = min(0, -deleteWidth + translation)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = value.translation.width < -deleteWidth / 2 ? -deleteWidth : 0
                            }
                        }
                )
        }
        .clipped()
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
    let options: [Double] = [1, 2, 3, 4, 6]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { value in
                let selected = abs(multiplier - value) < 0.01
                Button("\(Int(value))×") {
                    multiplier = value
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .clipShape(Capsule())
            }
            Spacer()
        }
    }
}
