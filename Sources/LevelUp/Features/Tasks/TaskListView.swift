import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var isAddingTask = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Aufgaben")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingTask) {
                AddTaskView()
            }
            .overlay {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "Keine Aufgaben",
                        systemImage: "checklist",
                        description: Text("Tippe auf + um eine Aufgabe oder Erinnerung anzulegen.")
                    )
                }
            }
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = tasks[index]
            NotificationManager.cancel(for: task)
            modelContext.delete(task)
        }
    }
}

private struct TaskRow: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack {
            Button {
                task.isDone.toggle()
                NotificationManager.schedule(for: task)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        if task.repeatWeekdays.isEmpty {
            return task.dueDate.formatted(date: .abbreviated, time: .shortened)
        } else {
            let symbols = Calendar.current.shortWeekdaySymbols
            let names = task.repeatWeekdays.sorted().map { symbols[$0 - 1] }
            let time = task.dueDate.formatted(date: .omitted, time: .shortened)
            return "Jede Woche: \(names.joined(separator: ", ")) um \(time)"
        }
    }
}

#Preview {
    TaskListView()
        .modelContainer(for: TaskItem.self, inMemory: true)
}
