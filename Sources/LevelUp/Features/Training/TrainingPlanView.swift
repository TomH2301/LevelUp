import SwiftUI
import SwiftData

struct TrainingPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [TrainingPlan]
    @Query private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            Group {
                if let plan = plans.first {
                    List {
                        ForEach(1...7, id: \.self) { weekday in
                            NavigationLink {
                                PlanDayEditView(plan: plan, weekday: weekday)
                            } label: {
                                weekdayRow(plan: plan, weekday: weekday)
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Trainingsplan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
        .task {
            if plans.isEmpty {
                modelContext.insert(TrainingPlan(name: "Mein Plan"))
            }
            if exercises.isEmpty {
                ExerciseSeeder.seed(into: modelContext)
            }
        }
    }

    private func weekdayRow(plan: TrainingPlan, weekday: Int) -> some View {
        let day = plan.days.first { $0.weekday == weekday }
        let symbol = Calendar.current.weekdaySymbols[weekday - 1]
        return HStack {
            Text(symbol)
            Spacer()
            if let day, !day.exercises.isEmpty {
                Text("\(day.exercises.count) Übung\(day.exercises.count == 1 ? "" : "en")")
                    .foregroundStyle(.secondary)
            } else {
                Text("Kein Training")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    TrainingPlanView()
        .modelContainer(for: [TrainingPlan.self, Exercise.self], inMemory: true)
}
