import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var engagements: [MuscleEngagement] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Übung") {
                    TextField("Name", text: $name)
                }

                Section("Beanspruchte Muskeln (Satz-Faktor)") {
                    ForEach(engagements.indices, id: \.self) { index in
                        HStack {
                            Picker("Muskel", selection: $engagements[index].muscleGroup) {
                                ForEach(MuscleGroup.allCases) { group in
                                    Text(group.displayName).tag(group)
                                }
                            }
                            .labelsHidden()

                            Spacer()

                            TextField("Faktor", value: $engagements[index].setFactor, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                        }
                    }
                    .onDelete { offsets in
                        engagements.remove(atOffsets: offsets)
                    }

                    Button {
                        engagements.append(MuscleEngagement(muscleGroup: .chest, setFactor: 1.0))
                    } label: {
                        Label("Muskel hinzufügen", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Neue Übung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || engagements.isEmpty)
                }
            }
        }
    }

    private func save() {
        let exercise = Exercise(name: name, muscleEngagements: engagements)
        modelContext.insert(exercise)
        dismiss()
    }
}

#Preview {
    AddExerciseView()
        .modelContainer(for: Exercise.self, inMemory: true)
}
