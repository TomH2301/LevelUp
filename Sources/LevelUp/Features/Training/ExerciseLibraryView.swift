import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var isAddingExercise = false

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(engagementSummary(exercise))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteExercises)
        }
        .navigationTitle("Übungen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingExercise) {
            AddExerciseView()
        }
    }

    private func engagementSummary(_ exercise: Exercise) -> String {
        exercise.muscleEngagements
            .sorted { $0.setFactor > $1.setFactor }
            .map { "\($0.muscleGroup.displayName) \($0.setFactor.formatted(.number.precision(.fractionLength(0...2))))" }
            .joined(separator: " · ")
    }

    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(exercises[index])
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
    }
    .modelContainer(for: Exercise.self, inMemory: true)
}
