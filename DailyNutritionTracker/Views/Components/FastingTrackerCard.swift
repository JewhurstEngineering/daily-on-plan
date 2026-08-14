import SwiftUI

/// Zero / EasyFast-style fasting clock. Same math as the day sheet — no social feed.
struct FastingTrackerCard: View {
    var log: DailyLog
    var previous: DailyLog?
    var settings: AppSettings
    var streak: Int = 0
    var compact: Bool = false
    var onChange: () -> Void = {}

    @Environment(\.accentPrimary) private var accent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            let phase = FastingMath.phase(today: log, previous: previous, settings: settings, now: now)
            content(phase: phase, now: now)
        }
    }

    @ViewBuilder
    private func content(phase: FastingPhase, now: Date) -> some View {
        let elapsed = elapsedInterval(phase)
        let target = targetInterval(phase)
        let progress = target > 0 ? min(max(elapsed / target, 0), 1) : 0
        let remaining = max(0, target - elapsed)
        let ringSize: CGFloat = compact ? 128 : 200

        VStack(spacing: compact ? 12 : 18) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: phase.isEating ? "fork.knife" : "flame.fill")
                    .foregroundStyle(accent)
                    .font(compact ? .title3 : .title2)
                Text(headline(phase))
                    .font(compact ? .title3.weight(.bold) : .title2.weight(.bold))
                Spacer(minLength: 8)
                Text(settings.fastingPreset.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent.opacity(0.16)))
                    .foregroundStyle(accent)
            }

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: compact ? 12 : 16)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.55), accent, accent.opacity(0.85)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: compact ? 12 : 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: progress)

                VStack(spacing: 4) {
                    Text(progressLabel(phase, progress: progress))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(FastingMath.formatClock(elapsed))
                        .font(compact ? .title.weight(.bold).monospacedDigit() : .largeTitle.weight(.bold).monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if remaining > 0, showsRemaining(phase) {
                        Text("Remaining \(FastingMath.formatDuration(remaining))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if hit(phase) {
                        Text("Target hit")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(accent.opacity(0.16)))
                            .foregroundStyle(accent)
                    }
                }
                .padding(compact ? 16 : 22)
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity)

            HStack(alignment: .top) {
                timeColumn(
                    title: leftStampTitle(phase),
                    value: leftStampValue(phase, now: now),
                    alignment: .leading
                )
                Spacer()
                timeColumn(
                    title: rightStampTitle(phase),
                    value: rightStampValue(phase, now: now),
                    alignment: .trailing
                )
            }

            primaryButton(phase)

            if !compact {
                Text(streak == 0 ? "No streak yet — hit the overnight target to start one." : (streak == 1 ? "1 day streak" : "\(streak) day streak"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func headline(_ phase: FastingPhase) -> String {
        switch phase {
        case .off: return "Fasting"
        case .fasting: return "You’re fasting"
        case .eating(_, _, _, let ended):
            return ended == nil ? "Eating window" : "Window closed"
        }
    }

    private func progressLabel(_ phase: FastingPhase, progress: Double) -> String {
        let pct = Int((progress * 100).rounded())
        switch phase {
        case .off: return "Turn fasting on in Settings"
        case .fasting: return "Elapsed time (\(pct)%)"
        case .eating(_, _, _, let ended):
            return ended == nil ? "Eating (\(pct)%)" : "Ate (\(pct)%)"
        }
    }

    private func elapsedInterval(_ phase: FastingPhase) -> TimeInterval {
        switch phase {
        case .off: return 0
        case .fasting(let elapsed, _): return elapsed
        case .eating(let elapsed, _, _, _): return elapsed
        }
    }

    private func targetInterval(_ phase: FastingPhase) -> TimeInterval {
        switch phase {
        case .off: return settings.fastingTargetHours * 3600
        case .fasting(_, let target): return target
        case .eating: return settings.fastingEatHours * 3600
        }
    }

    private func showsRemaining(_ phase: FastingPhase) -> Bool {
        switch phase {
        case .fasting: return true
        case .eating(_, _, _, let ended): return ended == nil
        default: return false
        }
    }

    private func hit(_ phase: FastingPhase) -> Bool {
        switch phase {
        case .fasting(let elapsed, let target): return elapsed + 60 >= target
        default: return FastingMath.hitTarget(today: log, previous: previous, settings: settings)
        }
    }

    private func leftStampTitle(_ phase: FastingPhase) -> String {
        switch phase {
        case .eating: return "Started eating"
        default: return "Started fasting"
        }
    }

    private func rightStampTitle(_ phase: FastingPhase) -> String {
        switch phase {
        case .eating(_, _, _, let ended):
            return ended == nil ? "Window ends" : "Closed"
        default: return "Eat at"
        }
    }

    private func leftStampValue(_ phase: FastingPhase, now: Date) -> String {
        switch phase {
        case .eating(_, _, let started, _):
            return DateHelpers.formattedTime(started)
        case .fasting:
            let anchor = FastingMath.previousWindowEnd(previous: previous, settings: settings)
                ?? FastingMath.typicalWindow(
                    on: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                    settings: settings
                ).end
            return DateHelpers.formattedTime(anchor)
        default:
            return "—"
        }
    }

    private func rightStampValue(_ phase: FastingPhase, now: Date) -> String {
        switch phase {
        case .eating(_, _, let started, let ended):
            if let ended { return DateHelpers.formattedTime(ended) }
            return DateHelpers.formattedTime(started.addingTimeInterval(settings.fastingEatHours * 3600))
        default:
            let window = FastingMath.typicalWindow(on: log.date, settings: settings)
            return DateHelpers.formattedTime(window.start)
        }
    }

    @ViewBuilder
    private func primaryButton(_ phase: FastingPhase) -> some View {
        switch phase {
        case .off:
            EmptyView()
        case .fasting:
            VStack(spacing: 8) {
                Button {
                    log.eatingWindowStart = Date()
                    log.eatingWindowEnd = nil
                    onChange()
                } label: {
                    Text("End Fast")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(compact ? .regular : .large)
                if !compact {
                    Button("Use typical window") {
                        FastingMath.applyTypicalWindow(to: log, settings: settings)
                        onChange()
                    }
                    .font(.caption)
                }
            }
        case .eating(_, _, _, let ended):
            if ended == nil {
                Button {
                    log.eatingWindowEnd = Date()
                    onChange()
                } label: {
                    Text("Close window")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(compact ? .regular : .large)
            } else {
                Button {
                    log.eatingWindowStart = nil
                    log.eatingWindowEnd = nil
                    onChange()
                } label: {
                    Text("Clear window")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(compact ? .regular : .large)
            }
        }
    }

    private func timeColumn(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
