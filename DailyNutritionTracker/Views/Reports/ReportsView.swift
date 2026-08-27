import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton: Bool = true

    @State private var range: ReportRange = .days30
    @State private var endDate = Date()
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var snapshot: ReportSnapshot?

    var body: some View {
        NavigationStack {
            List {
                Section("Range") {
                    Picker("Range", selection: $range) {
                        ForEach(ReportRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if range == .custom {
                        DatePicker("From", selection: $customStart, in: ...endDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                    }
                    if let snapshot {
                        Text("\(snapshot.logs.count) days logged · \(snapshot.start.formatted(.dateTime.month().day())) – \(snapshot.end.formatted(.dateTime.month().day()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.m) {
                            ReportMarqueeCard(
                                title: "What I’ve Been Eating",
                                subtitle: "Day-by-day food & drink",
                                systemImage: "list.bullet.rectangle"
                            ) {
                                EatingReportView(snapshot: currentSnapshot)
                            }
                            ReportMarqueeCard(
                                title: "Snapshot",
                                subtitle: "Average day + weekly rollups",
                                systemImage: "chart.bar.doc.horizontal"
                            ) {
                                SnapshotReportView(snapshot: currentSnapshot)
                            }
                            ReportMarqueeCard(
                                title: "Calendar heatmap",
                                subtitle: "Plan, water, protein & habit-free days",
                                systemImage: "calendar"
                            ) {
                                CalendarHeatmapView(snapshot: currentSnapshot)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Overview")
                }

                Section("Nutrition") {
                    NavigationLink {
                        ProteinReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Protein", systemImage: "fork.knife.circle")
                    }
                    NavigationLink {
                        ChecklistReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Fats, Veggies & More", systemImage: "leaf")
                    }
                    NavigationLink {
                        HydrationReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Hydration", systemImage: "drop.fill")
                    }
                    NavigationLink {
                        SupplementsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Supplements", systemImage: "pills")
                    }
                }

                Section("Body") {
                    NavigationLink {
                        WeightReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Weight & BMI", systemImage: "scalemass")
                    }
                    NavigationLink {
                        BodyCompositionReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Body composition", systemImage: "figure.arms.open")
                    }
                    NavigationLink {
                        TapeMeasurementsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Tape measurements", systemImage: "ruler")
                    }
                }

                Section("Activity & Habits") {
                    NavigationLink {
                        WorkoutReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Workouts", systemImage: "figure.run")
                    }
                    if currentSnapshot.showsSmokingReport {
                        NavigationLink {
                            SmokingReportView(snapshot: currentSnapshot)
                        } label: {
                            Label("Smoking", systemImage: "smoke")
                        }
                    }
                    if currentSnapshot.showsDrinkingReport {
                        NavigationLink {
                            DrinkingReportView(snapshot: currentSnapshot)
                        } label: {
                            Label("Drinking", systemImage: "wineglass")
                        }
                    }
                }

                Section("Wellbeing") {
                    NavigationLink {
                        FeelingsReportView(snapshot: currentSnapshot)
                    } label: {
                        Label("Feelings & Cravings", systemImage: "heart.text.square")
                    }
                    if currentSnapshot.showsBathroomReport {
                        NavigationLink {
                            BathroomReportView(snapshot: currentSnapshot)
                        } label: {
                            Label("Bathroom", systemImage: "toilet")
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .onAppear { refresh() }
            .onChange(of: range) { _, _ in refresh() }
            .onChange(of: endDate) { _, _ in refresh() }
            .onChange(of: customStart) { _, _ in refresh() }
        }
    }

    private var currentSnapshot: ReportSnapshot {
        snapshot ?? ReportAggregator.snapshot(
            range: range,
            endDate: endDate,
            customStart: customStart,
            in: modelContext
        )
    }

    private func refresh() {
        snapshot = ReportAggregator.snapshot(
            range: range,
            endDate: endDate,
            customStart: customStart,
            in: modelContext
        )
    }
}

// MARK: - Shared report chrome

struct ReportMetricRow: View {
    let title: String
    let value: String
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(valueColor ?? .primary)
        }
        .font(.subheadline)
    }
}

/// The three marquee-weight reports (Eating report, Snapshot, Calendar heatmap) get a bigger,
/// scannable tile instead of blending into the flat list of section reports below them.
struct ReportMarqueeCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 168, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct EmptyReportHint: View {
    var body: some View {
        ContentUnavailableView(
            "No data in range",
            systemImage: "chart.bar",
            description: Text("Log a few days, then reopen reports.")
        )
    }
}

// Per-section report screens live in DetailReportViews.swift, rebuilt in the Trends card style.
