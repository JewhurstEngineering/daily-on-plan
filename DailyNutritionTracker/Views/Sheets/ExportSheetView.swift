import SwiftUI
import SwiftData

struct ExportSheetView: View {
    let selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var range: ExportRange = .week
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var shareItem: ShareableExport?
    @State private var isExporting = false
    @State private var statusMessage: String?
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
                } footer: {
                    Text("Exports include logs and weights in the selected range.")
                }

                Section {
                    exportButton(
                        title: "Excel workbook (.xlsx)",
                        subtitle: "One sheet per day — opens in Excel, Numbers, and Google Sheets.",
                        systemImage: "tablecells",
                        kind: .workbook
                    )
                    exportButton(
                        title: "PDF report",
                        subtitle: "Printable day-by-day summary.",
                        systemImage: "doc.richtext",
                        kind: .pdf
                    )
                    exportButton(
                        title: "CSV spreadsheet",
                        subtitle: "Flat rows for Numbers, Sheets, or analysis tools.",
                        systemImage: "tablecells.badge.ellipsis",
                        kind: .csv
                    )
                } header: {
                    Text("Formats")
                }

                if isExporting {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing export…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Export")
            .disabled(isExporting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    @ViewBuilder
    private func exportButton(
        title: String,
        subtitle: String,
        systemImage: String,
        kind: ExportKind
    ) -> some View {
        Button {
            runExport(kind)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }

    private enum ExportKind { case workbook, pdf, csv }

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
        let weights = DataStore.weights(from: start, to: end, in: modelContext)
        return (settings, logs, weights, start, end)
    }

    private func filenameStem(start: Date, end: Date) -> String {
        let startText = start.formatted(.iso8601.year().month().day())
        let endText = end.formatted(.iso8601.year().month().day())
        return "daily-on-plan-\(startText)-to-\(endText)"
    }

    private func runExport(_ kind: ExportKind) {
        errorMessage = nil
        statusMessage = nil
        isExporting = true

        // Yield so the progress row can paint before heavier work.
        DispatchQueue.main.async {
            do {
                let dataPack = fetchData()
                let stem = filenameStem(start: dataPack.start, end: dataPack.end)
                let url: URL
                switch kind {
                case .workbook:
                    url = try WorkbookExportService.writeTemporaryFile(
                        logs: dataPack.logs,
                        weights: dataPack.weights,
                        settings: dataPack.settings,
                        filenameStem: stem
                    )
                case .pdf:
                    let title = "\(AppIdentity.displayName) — \(range.title) Report"
                    url = try ExportService.writePDFFile(
                        logs: dataPack.logs,
                        weights: dataPack.weights,
                        settings: dataPack.settings,
                        title: title,
                        filenameStem: stem
                    )
                case .csv:
                    url = try ExportService.writeCSVFile(
                        logs: dataPack.logs,
                        weights: dataPack.weights,
                        settings: dataPack.settings,
                        filenameStem: stem
                    )
                }
                isExporting = false
                statusMessage = "Ready: \(url.lastPathComponent)"
                // Brief delay so the export form can settle before the share sheet presents.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    shareItem = ShareableExport(url: url)
                }
            } catch {
                isExporting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ShareableExport: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            // iPad requires a source; sheet presentation supplies a fallback.
            popover.sourceView = UIView()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
