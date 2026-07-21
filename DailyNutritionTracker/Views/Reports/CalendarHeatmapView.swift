import SwiftUI

struct CalendarHeatmapView: View {
    let snapshot: ReportSnapshot
    @State private var metric: HeatmapMetric = .followedPlan
    @State private var monthAnchor: Date = Date()
    @State private var shareURL: URL?
    @State private var isRendering = false

    private var metrics: [HeatmapMetric] {
        snapshot.availableHeatmapMetrics
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if snapshot.logs.isEmpty {
                    EmptyReportHint()
                } else {
                    Picker("Metric", selection: $metric) {
                        ForEach(metrics) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.menu)

                    monthHeader

                    HeatmapMonthGrid(
                        month: monthAnchor,
                        days: daysInVisibleMonth,
                        accent: Color.accentColor
                    )

                    legend

                    Text("\(hitCount) of \(loggedInMonth) logged days met “\(metric.title)” this month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Heatmap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shareHeatmap()
                } label: {
                    if isRendering {
                        ProgressView()
                    } else {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isRendering || snapshot.logs.isEmpty)
            }
        }
        .onAppear {
            monthAnchor = DateHelpers.startOfDay(snapshot.end)
            if !metrics.contains(metric), let first = metrics.first {
                metric = first
            }
        }
        .onChange(of: metric) { _, _ in }
        .sheet(item: Binding(
            get: { shareURL.map { ShareableImageURL(url: $0) } },
            set: { shareURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var daysInVisibleMonth: [HeatmapDay] {
        let calendar = Calendar.current
        let all = snapshot.heatmapDays(for: metric)
        return all.filter { calendar.isDate($0.date, equalTo: monthAnchor, toGranularity: .month) }
    }

    private var loggedInMonth: Int {
        daysInVisibleMonth.filter { $0.hit != nil }.count
    }

    private var hitCount: Int {
        daysInVisibleMonth.filter { $0.hit == true }.count
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canShift(-1))

            Spacer()
            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canShift(1))
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendSwatch(Color.accentColor.opacity(0.85), "Hit")
            legendSwatch(Color.orange.opacity(0.75), "Miss")
            legendSwatch(Color(.tertiarySystemFill), "No log")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendSwatch(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(title)
        }
    }

    private func canShift(_ delta: Int) -> Bool {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) else { return false }
        let startMonth = Calendar.current.dateInterval(of: .month, for: snapshot.start)?.start ?? snapshot.start
        let endMonth = Calendar.current.dateInterval(of: .month, for: snapshot.end)?.start ?? snapshot.end
        let nextMonth = Calendar.current.dateInterval(of: .month, for: next)?.start ?? next
        return nextMonth >= startMonth && nextMonth <= endMonth
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        monthAnchor = next
    }

    @MainActor
    private func shareHeatmap() {
        isRendering = true
        let card = HeatmapShareCard(
            month: monthAnchor,
            metric: metric,
            days: daysInVisibleMonth,
            brand: AppIdentity.displayName
        )
        Task { @MainActor in
            defer { isRendering = false }
            if let url = ShareCardRenderer.writePNG(of: card, size: CGSize(width: 360, height: 420)) {
                shareURL = url
            }
        }
    }
}

struct HeatmapMonthGrid: View {
    let month: Date
    let days: [HeatmapDay]
    var accent: Color = .accentColor
    var cellSize: CGFloat = 28
    var showWeekdayLabels: Bool = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var byDay: [Date: HeatmapDay] {
        Dictionary(uniqueKeysWithValues: days.map { (DateHelpers.startOfDay($0.date), $0) })
    }

    private var cells: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start) // 1 = Sunday
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        var cursor = interval.start
        while cursor < interval.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showWeekdayLabels {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let day = byDay[DateHelpers.startOfDay(date)]
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(fill(for: day?.hit))
                            .frame(height: cellSize)
                            .overlay {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(day?.hit == nil ? Color.secondary : Color.white.opacity(0.95))
                            }
                            .accessibilityLabel(accessibilityLabel(date: date, hit: day?.hit))
                    } else {
                        Color.clear.frame(height: cellSize)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let first = Calendar.current.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func fill(for hit: Bool?) -> Color {
        switch hit {
        case .some(true): return accent.opacity(0.85)
        case .some(false): return Color.orange.opacity(0.75)
        case .none: return Color(.tertiarySystemFill)
        }
    }

    private func accessibilityLabel(date: Date, hit: Bool?) -> String {
        let day = date.formatted(.dateTime.month().day())
        switch hit {
        case .some(true): return "\(day), hit"
        case .some(false): return "\(day), miss"
        case .none: return "\(day), no log"
        }
    }
}

private struct ShareableImageURL: Identifiable {
    var id: String { url.absoluteString }
    let url: URL
}
