import SwiftUI

struct BasicDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: AvatarProfile

    @State private var heightText: String = ""
    @State private var weightText: String = ""
    @State private var ageText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Grunddaten") {
                    HStack {
                        Text("Größe")
                        Spacer()
                        TextField("cm", text: $heightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Gewicht")
                        Spacer()
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Alter")
                        Spacer()
                        TextField("Jahre", text: $ageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("Jahre").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Daraus wird dein Avatar-Startzustand geschätzt (Körperfett, Muskelmasse), solange noch keine eigenen Mess- oder Trainingswerte vorliegen. Das Gewicht hier zählt nur, bis du den ersten Eintrag im Körper-Tab anlegst — danach übernimmt der.")
                }
            }
            .navigationTitle("Grunddaten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                heightText = String(format: "%.0f", profile.heightCm)
                weightText = String(format: "%.1f", profile.fallbackWeightKg)
                ageText = String(profile.age)
            }
        }
    }

    private var isValid: Bool {
        heightValue != nil && weightValue != nil && ageValue != nil
    }

    private var heightValue: Double? { Double(heightText) }
    private var weightValue: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    private var ageValue: Int? { Int(ageText) }

    private func save() {
        guard let height = heightValue, let weight = weightValue, let age = ageValue else { return }
        profile.heightCm = height
        profile.fallbackWeightKg = weight
        profile.age = age
        dismiss()
    }
}

#Preview {
    BasicDataView(profile: AvatarProfile())
}
