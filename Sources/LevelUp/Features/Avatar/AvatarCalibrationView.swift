import SwiftUI

struct AvatarCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: AvatarProfile

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $profile.minBodyFatPercent, in: 3...profile.maxBodyFatPercent - 1, step: 1) {
                        Text("Min: \(Int(profile.minBodyFatPercent)) %")
                    }
                    Stepper(value: $profile.maxBodyFatPercent, in: profile.minBodyFatPercent + 1...60, step: 1) {
                        Text("Max: \(Int(profile.maxBodyFatPercent)) %")
                    }
                } header: {
                    Text("Körperfett-Spanne")
                } footer: {
                    Text("Bei diesem KFA-Wert zeigt der Avatar 0 % bzw. 100 % der Fat-Achse.")
                }

                Section {
                    Stepper(value: $profile.minLeanMassIndex, in: 10...profile.maxLeanMassIndex - 1, step: 1) {
                        Text("Min: \(Int(profile.minLeanMassIndex))")
                    }
                    Stepper(value: $profile.maxLeanMassIndex, in: profile.minLeanMassIndex + 1...30, step: 1) {
                        Text("Max: \(Int(profile.maxLeanMassIndex))")
                    }
                } header: {
                    Text("Fettfreie-Masse-Spanne")
                } footer: {
                    Text("Normalisiert den aus Gewicht/KFA geschätzten Muskel-Proxy. Typische Werte: 16 (schlank) bis 24 (sehr muskulös).")
                }

                Section {
                    Stepper(value: $profile.maxStrengthLevel, in: 5...100, step: 5) {
                        Text("Kraft-Level für 100 %: \(profile.maxStrengthLevel)")
                    }
                } header: {
                    Text("Kraft-Level-Spanne")
                }

                Section {
                    Slider(value: $profile.trainingInfluence, in: 0...1, step: 0.1)
                    HStack {
                        Text("Schätzung")
                        Spacer()
                        Text("\(Int(profile.trainingInfluence * 100)) % Training")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Training")
                    }
                    .font(.caption)
                } header: {
                    Text("Muscular-Mischverhältnis")
                } footer: {
                    Text("Wie stark dein Kraft-Level den Fettfreie-Masse-Startwert für die Muscular-Achse überschreibt. 0 % = nur Schätzung, 100 % = nur Trainingsfortschritt.")
                }
            }
            .navigationTitle("Kalibrierung")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AvatarCalibrationView(profile: AvatarProfile())
}
