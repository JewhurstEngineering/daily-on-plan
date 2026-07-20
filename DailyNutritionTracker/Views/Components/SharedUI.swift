import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    var systemImage: String? = nil
    @ViewBuilder var content: Content

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
    let index: Int
    let filledCount: Int
    let action: () -> Void

    private var isFilled: Bool { index < filledCount }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isFilled ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.title3)
                    .foregroundStyle(isFilled ? Color.accentColor : Color.secondary)
                Text("8oz")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isFilled ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
