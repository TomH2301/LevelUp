import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]
    @State private var isPickingExercise = false

    var body: some View {
        List {
            Section {
                RestTimerBar()
            }

            ForEach(exercisesInSession) { exercise in
                Section(exercise.name) {
                    ForEach(sets(for: exercise)) { entry in
                        SetRowView(entry: entry, previous: previousEntry(for: exercise, setNumber: entry.setNumber))
                    }
                    Button {
                        addSet(for: exercise)
                    } label: {
                        Label("Satz hinzufügen", systemImage: "plus")
                    }
                }
            }

            Section {
                Button {
                    isPickingExercise = true
                } label: {
                    Label("Übung hinzufügen", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
        .sheet(isPresented: $isPickingExercise) {
            ExercisePickerView(exercises: allExercises) { exercise in
                addSet(for: exercise)
            }
        }
    }

    private var exercisesInSession: [Exercise] {
        var seen = Set<PersistentIdentifier>()
        var result: [Exercise] = []
        for entry in session.setEntries.sorted(by: { $0.setNumber < $1.setNumber }) {
            if let exercise = entry.exercise, !seen.contains(exercise.persistentModelID) {
                seen.insert(exercise.persistentModelID)
                result.append(exercise)
            }
        }
        return result
    }

    private func sets(for exercise: Exercise) -> [SetEntry] {
        session.setEntries
            .filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
            .sorted { $0.setNumber < $1.setNumber }
    }

    private func addSet(for exercise: Exercise) {
        let currentCount = sets(for: exercise).count
        let newEntry = SetEntry(exercise: exercise, setNumber: currentCount + 1, weightKg: 0, reps: 0)
        newEntry.session = session
        modelContext.insert(newEntry)
    }

    private func previousEntry(for exercise: Exercise, setNumber: Int) -> SetEntry? {
        for pastSession in allSessions
        where pastSession.persistentModelID != session.persistentModelID && pastSession.date < session.date {
            if let match = pastSession.setEntries.first(where: {
                $0.exercise?.persistentModelID == exercise.persistentModelID && $0.setNumber == setNumber
            }) {
                return match
            }
        }
        return nil
    }
}

private struct SetRowView: View {
    @Bindable var entry: SetEntry
    let previous: SetEntry?

    var body: some View {
        HStack {
            Text("Satz \(entry.setNumber)")
                .frame(width: 55, alignment: .leading)
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("kg", value: $entry.weightKg, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 55)
            Text("kg")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Wdh.", value: $entry.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 35)
            Text("Wdh.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            comparisonIndicator
        }
    }

    @ViewBuilder
    private var comparisonIndicator: some View {
        if let previous, previous.weightKg > 0 || previous.reps > 0 {
            let currentVolume = entry.weightKg * Double(entry.reps)
            let previousVolume = previous.weightKg * Double(previous.reps)
            if currentVolume > previousVolume {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green)
            } else if currentVolume < previousVolume {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red)
            } else {
                Image(systemName: "equal.circle.fill").foregroundStyle(.secondary)
            }
        }
    }
}
