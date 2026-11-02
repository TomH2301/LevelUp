import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let exercises: [Exercise]
    let onPick: (Exercise) -> Void

    var body: some View {
        NavigationStack {
            List(exercises) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    Text(exercise.name)
                        .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Übung wählen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
