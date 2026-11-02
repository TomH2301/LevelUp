import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var repeatsWeekly = false
    @State private var selectedWeekdays: Set<Int> = []

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            Form {
                Section("Aufgabe") {
                    TextField("Titel", text: $title)
                }

                Section("Fälligkeit") {
                    Toggle("Wiederholt sich wöchentlich", isOn: $repeatsWeekly.animation())

                    if repeatsWeekly {
                        weekdayPicker
                        DatePicker("Uhrzeit", selection: $dueDate, displayedComponents: .hourAndMinute)
                    } else {
                        DatePicker("Fällig am", selection: $dueDate)
                    }
                }
            }
            .navigationTitle("Neue Aufgabe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty || (repeatsWeekly && selectedWeekdays.isEmpty)
    }

    private var weekdayPicker: some View {
        HStack {
            ForEach(1...7, id: \.self) { weekday in
                let symbol = weekdaySymbols[weekday - 1]
                let isSelected = selectedWeekdays.contains(weekday)
                Button(symbol) {
                    if isSelected {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .blue : .gray)
            }
        }
        .font(.caption)
    }

    private func save() {
        let task = TaskItem(
            title: title,
            dueDate: dueDate,
            repeatWeekdays: repeatsWeekly ? Array(selectedWeekdays) : []
        )
        modelContext.insert(task)
        NotificationManager.schedule(for: task)
        dismiss()
    }
}

#Preview {
    AddTaskView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
