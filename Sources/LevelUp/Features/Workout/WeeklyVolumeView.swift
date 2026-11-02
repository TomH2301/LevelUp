import SwiftUI
import SwiftData

struct WeeklyVolumeView: View {
    @Query private var sessions: [WorkoutSession]
    @AppStorage("weeklySetThreshold") private var threshold: Double = 17

    var body: some View {
        List {
            Section {
                Stepper(value: $threshold, in: 5...30, step: 1) {
                    Text("100 % = \(Int(threshold)) Sätze/Woche")
                }
            } footer: {
                Text("Diese Schwelle gilt für alle Muskelgruppen gleich und ist frei einstellbar.")
            }

            Section("Diese Woche") {
                if volumesByMuscle.isEmpty {
                    Text("Noch kein Training diese Woche erfasst.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(volumesByMuscle, id: \.0) { muscle, sets in
                        VolumeRow(muscle: muscle, sets: sets, threshold: threshold)
                    }
                }
            }
        }
        .navigationTitle("Wochenauslastung")
    }

    private var weekRange: Range<Date> {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? .now
        return start..<end
    }

    private var volumesByMuscle: [(MuscleGroup, Double)] {
        var totals: [MuscleGroup: Double] = [:]
        for session in sessions where weekRange.contains(session.date) {
            for entry in session.setEntries {
                guard let exercise = entry.exercise else { continue }
                for engagement in exercise.muscleEngagements {
                    totals[engagement.muscleGroup, default: 0] += engagement.setFactor
                }
            }
        }
        return MuscleGroup.allCases
            .map { ($0, totals[$0] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }
}

private struct VolumeRow: View {
    let muscle: MuscleGroup
    let sets: Double
    let threshold: Double

    private var percentage: Double {
        threshold > 0 ? sets / threshold : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(muscle.displayName)
                Spacer()
                Text("\(sets.formatted(.number.precision(.fractionLength(0...1)))) / \(Int(threshold)) Sätze")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            ProgressView(value: min(percentage, 1.0))
                .tint(percentage >= 1.0 ? .green : (percentage >= 0.5 ? .blue : .orange))
        }
    }
}

#Preview {
    NavigationStack {
        WeeklyVolumeView()
    }
    .modelContainer(for: WorkoutSession.self, inMemory: true)
}
