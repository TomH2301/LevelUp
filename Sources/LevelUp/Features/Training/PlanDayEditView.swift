import SwiftUI
import SwiftData

struct PlanDayEditView: View {
    @Environment(\.modelContext) private var modelContext
    let plan: TrainingPlan
    let weekday: Int

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var isPickingExercise = false

    private var day: PlanDay? {
        plan.days.first { $0.weekday == weekday }
    }

    private var weekdayName: String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    var body: some View {
        List {
            if let day, !day.exercises.isEmpty {
                ForEach(day.exercises) { planExercise in
                    HStack {
                        Text(planExercise.exercise?.name ?? "—")
                        Spacer()
                        Stepper(value: Binding(
                            get: { planExercise.targetSets },
                            set: { planExercise.targetSets = $0 }
                        ), in: 1...10) {
                            Text("\(planExercise.targetSets) Sätze")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deletePlanExercises)
            } else {
                ContentUnavailableView(
                    "Kein Training an diesem Tag",
                    systemImage: "calendar",
                    description: Text("Tippe auf + um eine Übung hinzuzufügen.")
                )
            }
        }
        .navigationTitle(weekdayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPickingExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPickingExercise) {
            ExercisePickerView(exercises: allExercises) { exercise in
                addExercise(exercise)
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let targetDay: PlanDay
        if let existing = day {
            targetDay = existing
        } else {
            let newDay = PlanDay(weekday: weekday)
            newDay.plan = plan
            modelContext.insert(newDay)
            targetDay = newDay
        }
        let planExercise = PlanExercise(exercise: exercise, targetSets: 3)
        planExercise.planDay = targetDay
        modelContext.insert(planExercise)
    }

    private func deletePlanExercises(at offsets: IndexSet) {
        guard let day else { return }
        for index in offsets {
            modelContext.delete(day.exercises[index])
        }
    }
}
