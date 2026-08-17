import SwiftUI

/// Fasting clock. Only the dial ticks — the rest of the card stays still.
struct FastingTrackerCard: View {
    var log: DailyLog
    var previous: DailyLog?
    var settings: AppSettings
    var streak: Int = 0
    var compact: Bool = false
    var onChange: () -> Void = {}

    @Environment(\.accentPrimary) private var accent
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let now = Date()
        let phase = FastingMath.phase(today: log, previous: previous, settings: settings, now: now)
        VStack(spacing: compact ? 12 : 18) {
            header(phase)
            liveDial(initialPhase: phase)
            stamps(phase, now: now)
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

    private var tickInterval: TimeInterval { compact ? 15 : 1 }

    private func shouldTick(_ phase: FastingPhase) -> Bool {
        if scenePhase != .active { return false }
        switch phase {
        case .fasting, .eating(_, _, _, nil): return true
        default: return false
        }
    }

    @ViewBuilder
    private func liveDial(initialPhase: FastingPhase) -> some View {
        if shouldTick(initialPhase) {
            TimelineView(.periodic(from: .now, by: tickInterval)) { timeline in
                let phase = FastingMath.phase(
                    today: log,
                    previous: previous,
                    settings: settings,
                    now: timeline.date
                )
                dial(phase: phase)
                    .transaction { $0.animation = nil }
            }
        } else {
            dial(phase: initialPhase)
        }
    }

    private func header(_ phase: FastingPhase) -> some View {
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
    }

    private func dial(phase: FastingPhase) -> some View {
        let elapsed = elapsedInterval(phase)
        let target = targetInterval(phase)
        let progress = target > 0 ? min(max(elapsed / target, 0), 1) : 0
        let remaining = max(0, target - elapsed)
        let ringSize: CGFloat = compact ? 128 : 200
        let lineWidth: CGFloat = compact ? 12 : 16

        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(progressLabel(phase, progress: progress))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(FastingMath.formatClock(elapsed, seconds: !compact))
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
    }

    private func stamps(_ phase: FastingPhase, now: Date) -> some View {
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
    }

    private func headline(_ phase: FastingPhase) -> String {
        switch phase {
        case .off: return "Fasting"
        case .idle: return "Ready to fast"
        case .fasting: return "You’re fasting"
        case .eating(_, _, _, let ended):
            return ended == nil ? "Eating window" : "Window closed"
        }
    }

    private func progressLabel(_ phase: FastingPhase, progress: Double) -> String {
        let pct = Int((progress * 100).rounded())
        switch phase {
        case .off: return "Turn fasting on in Settings"
        case .idle: return "Clock starts when you do"
        case .fasting: return "Elapsed time (\(pct)%)"
        case .eating(_, _, _, let ended):
            return ended == nil ? "Eating (\(pct)%)" : "Ate (\(pct)%)"
        }
    }

    private func elapsedInterval(_ phase: FastingPhase) -> TimeInterval {
        switch phase {
        case .off, .idle: return 0
        case .fasting(let elapsed, _): return elapsed
        case .eating(let elapsed, _, _, _): return elapsed
        }
    }

    private func targetInterval(_ phase: FastingPhase) -> TimeInterval {
        switch phase {
        case .off, .idle: return settings.fastingTargetHours * 3600
        case .fasting(_, let target): return target
        case .eating: return settings.fastingEatHours * 3600
        }
    }

    private func showsRemaining(_ phase: FastingPhase) -> Bool {
        switch phase {
        case .idle, .fasting: return true
        case .eating(_, _, _, let ended): return ended == nil
        default: return false
        }
    }

    private func hit(_ phase: FastingPhase) -> Bool {
        switch phase {
        case .fasting(let elapsed, let target): return elapsed + 60 >= target
        case .idle, .off: return false
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
            return DateHelpers.formattedTimeStamp(started, relativeTo: now)
        case .fasting:
            if let anchor = FastingMath.fastAnchor(today: log, previous: previous, settings: settings, now: now) {
                return DateHelpers.formattedTimeStamp(anchor, relativeTo: now)
            }
            return "—"
        default:
            return "—"
        }
    }

    private func rightStampValue(_ phase: FastingPhase, now: Date) -> String {
        switch phase {
        case .eating(_, _, let started, let ended):
            if let ended { return DateHelpers.formattedTimeStamp(ended, relativeTo: now) }
            return DateHelpers.formattedTimeStamp(started.addingTimeInterval(settings.fastingEatHours * 3600), relativeTo: now)
        case .fasting, .idle:
            if let anchor = FastingMath.fastAnchor(today: log, previous: previous, settings: settings, now: now) {
                return DateHelpers.formattedTimeStamp(
                    anchor.addingTimeInterval(settings.fastingTargetHours * 3600),
                    relativeTo: now
                )
            }
            return DateHelpers.formattedTimeStamp(
                now.addingTimeInterval(settings.fastingTargetHours * 3600),
                relativeTo: now
            )
        default:
            return "—"
        }
    }

    @ViewBuilder
    private func primaryButton(_ phase: FastingPhase) -> some View {
        switch phase {
        case .off:
            EmptyView()
        case .idle:
            Button {
                FastingMath.startFast(today: log)
                onChange()
            } label: {
                Text("Start Fast")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(compact ? .regular : .large)
        case .fasting:
            VStack(spacing: 8) {
                if log.eatingWindowStart != nil, log.eatingWindowEnd != nil {
                    Button {
                        log.eatingWindowEnd = nil
                        onChange()
                    } label: {
                        Text("Reopen window")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(compact ? .regular : .large)
                } else {
                    Button {
                        FastingMath.beginEating(today: log, previous: previous)
                        onChange()
                    } label: {
                        Text("End Fast")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(compact ? .regular : .large)
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
