import SwiftUI
import Charts

struct ReportChartGuideToggles: View {
    @Binding var showGoal: Bool
    @Binding var showStart: Bool
    @Binding var showTrend: Bool
    var hasGoal: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if hasGoal {
                chip("Goal", color: .orange, isOn: $showGoal)
            }
            chip("Start", color: .blue, isOn: $showStart)
            chip("Trend", color: .purple, isOn: $showTrend)
        }
        .controlSize(.small)
    }

    private func chip(_ title: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.button)
            .tint(color)
            .accessibilityLabel("\(title) line")
            .accessibilityHint(isOn.wrappedValue ? "Shown on the chart. Double tap to hide." : "Hidden. Double tap to show.")
    }
}

enum ReportSeriesGuides {
    @ChartContentBuilder
    static func marks(
        series: [DailyMetricPoint],
        yLabel: String,
        goal: Double?,
        showGoal: Bool,
        showStart: Bool,
        showTrend: Bool
    ) -> some ChartContent {
        ForEach(series) { point in
            LineMark(
                x: .value("Day", point.date),
                y: .value(yLabel, point.value),
                series: .value("Series", yLabel)
            )
            .foregroundStyle(Color.accentColor)
            PointMark(
                x: .value("Day", point.date),
                y: .value(yLabel, point.value)
            )
            .foregroundStyle(Color.accentColor)
        }

        if showGoal, let goal {
            RuleMark(y: .value("Goal", goal))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(dash: [4, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
        }

        if showStart, let start = series.first {
            RuleMark(y: .value("Start", start.value))
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(dash: [4, 3]))
                .annotation(position: .top, alignment: .leading) {
                    Text("Start")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
        }

        if showTrend,
           let trend = ChartTrendLine.leastSquares(
               dates: series.map(\.date),
               values: series.map(\.value)
           ) {
            ForEach(
                [
                    (id: "trend-start", date: trend.startDate, value: trend.startValue),
                    (id: "trend-end", date: trend.endDate, value: trend.endValue)
                ],
                id: \.id
            ) { point in
                LineMark(
                    x: .value("Day", point.date),
                    y: .value(yLabel, point.value),
                    series: .value("Series", "Trend")
                )
            }
            .foregroundStyle(.purple)
            .lineStyle(StrokeStyle(dash: [6, 4]))
        }
    }

    static func domainValues(series: [DailyMetricPoint], showTrend: Bool) -> [Double] {
        var values = series.map(\.value)
        if showTrend,
           let trend = ChartTrendLine.leastSquares(
               dates: series.map(\.date),
               values: series.map(\.value)
           ) {
            values.append(trend.startValue)
            values.append(trend.endValue)
        }
        return values
    }
}
