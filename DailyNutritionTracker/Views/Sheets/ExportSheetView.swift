import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportSheetView: View {
    let selectedDate: Date
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var range: ExportRange = .week
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var errorMessage: String?

    enum ExportRange: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Range", selection: $range) {
                    ForEach(ExportRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Button("Export PDF") { export(pdf: true) }
                Button("Export CSV") { export(pdf: false) }

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

    private func export(pdf: Bool) {
        let settings = DataStore.settings(in: modelContext)
        let calendar = Calendar.current
        let end = DateHelpers.startOfDay(selectedDate)
        let start: Date
        switch range {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        case .month:
            start = calendar.date(byAdding: .day, value: -29, to: end) ?? end
        }

        let logs = DataStore.logs(from: start, to: end, in: modelContext)
        let weights = DataStore.recentWeights(limit: 60, in: modelContext)
            .filter { $0.date >= start && $0.date <= end }
            .sorted { $0.date < $1.date }

        let title = "Daily Nutrition — \(range.title) Report"
        let data: Data
        let filename: String
        if pdf {
            data = ExportService.pdfData(logs: logs, weights: weights, settings: settings, title: title)
            filename = "nutrition-\(range.rawValue).pdf"
        } else {
            let csv = ExportService.csv(logs: logs, weights: weights, settings: settings)
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
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
