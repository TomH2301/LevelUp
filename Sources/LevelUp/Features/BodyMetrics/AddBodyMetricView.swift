import SwiftUI
import SwiftData

struct AddBodyMetricView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var weightText = ""
    @State private var bodyFatText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Datum") {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                }

                Section("Werte") {
                    HStack {
                        Text("Gewicht")
                        Spacer()
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Körperfett (optional)")
                        Spacer()
                        TextField("%", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Neuer Eintrag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(weightValue == nil)
                }
            }
        }
    }

    private var weightValue: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    private var bodyFatValue: Double? {
        Double(bodyFatText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let weight = weightValue else { return }
        let entry = BodyMetricEntry(date: date, weightKg: weight, bodyFatPercentage: bodyFatValue)
        modelContext.insert(entry)
        dismiss()
    }
}

#Preview {
    AddBodyMetricView()
        .modelContainer(for: BodyMetricEntry.self, inMemory: true)
}
