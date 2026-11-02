import SwiftUI
import SwiftData

struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var type: ActivityType = .reading
    @State private var date = Date()
    @State private var minutesText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Aktivität") {
                    Picker("Typ", selection: $type) {
                        ForEach(ActivityType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Dauer")
                        Spacer()
                        TextField("Minuten", text: $minutesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("Min")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Aktivität loggen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(Int(minutesText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let minutes = Int(minutesText) else { return }
        let log = ActivityLog(type: type, date: date, minutes: minutes)
        modelContext.insert(log)
        dismiss()
    }
}

#Preview {
    AddActivityView()
        .modelContainer(for: ActivityLog.self, inMemory: true)
}
