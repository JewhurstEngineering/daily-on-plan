import SwiftUI
import SwiftData

struct ExportSheetView: View {
    let selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var range: ExportRange = .week
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var errorMessage: String?

    enum ExportRange: String, CaseIterable, Identifiable {
        case day, week, month, custom
        var id: String { rawValue }
        var title: String {
            switch self {
            case .day: return "1 day"
            case .week: return "7 days"
            case .month: return "30 days"
            case .custom: return "Custom"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Range", selection: $range) {
                        ForEach(ExportRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if range == .custom {
                        DatePicker("From", selection: $customStart, in: ...selectedDate, displayedComponents: .date)
                        Text("Through \(DateHelpers.formattedDay(selectedDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Formats") {
                    Button {
                        exportWorkbook()
                    } label: {
                        Label("Export workbook (Excel)", systemImage: "tablecells")
                    }
                    Text("One sheet per day, laid out like the paper log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Export PDF") { export(kind: .pdf) }
                    Button("Export CSV") { export(kind: .csv) }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Export")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
        }
    }

    private enum Kind { case pdf, csv }

    private func dateBounds() -> (Date, Date) {
        let calendar = Calendar.current
        let end = DateHelpers.startOfDay(selectedDate)
        let start: Date
        switch range {
        case .day:
            start = end
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: end) ?? end
        case .custom:
            start = DateHelpers.startOfDay(customStart)
        }
        return (start, end)
    }

    private func fetchData() -> (settings: AppSettings, logs: [DailyLog], weights: [WeightEntry], start: Date, end: Date) {
        let settings = DataStore.settings(in: modelContext)
        let (start, end) = dateBounds()
        let logs = DataStore.logs(from: start, to: end, in: modelContext)
        let weights = DataStore.recentWeights(limit: 120, in: modelContext)
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }
        return (settings, logs, weights, start, end)
    }

    private func export(kind: Kind) {
        let dataPack = fetchData()
        let title = "Daily Nutrition — \(range.title) Report"
        let data: Data
        let filename: String
        switch kind {
        case .pdf:
            data = ExportService.pdfData(
                logs: dataPack.logs,
                weights: dataPack.weights,
                settings: dataPack.settings,
                title: title
            )
            filename = "nutrition-\(range.rawValue).pdf"
        case .csv:
            let csv = ExportService.csv(
                logs: dataPack.logs,
                weights: dataPack.weights,
                settings: dataPack.settings
            )
            data = Data(csv.utf8)
            filename = "nutrition-\(range.rawValue).csv"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            shareURL = url
            showShare = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportWorkbook() {
        let dataPack = fetchData()
        let stem = "nutrition-\(dataPack.start.formatted(.iso8601.year().month().day()))-to-\(dataPack.end.formatted(.iso8601.year().month().day()))"
        do {
            let url = try WorkbookExportService.writeTemporaryFile(
                logs: dataPack.logs,
                weights: dataPack.weights,
                settings: dataPack.settings,
                filenameStem: stem
            )
            shareURL = url
            showShare = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
