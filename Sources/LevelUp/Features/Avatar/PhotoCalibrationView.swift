import SwiftUI
import PhotosUI

struct PhotoCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: AvatarProfile

    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var detectedSkinHex: String?
    @State private var detectedHairHex: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Foto") {
                    PhotosPicker("Foto auswählen", selection: $selectedItem, matching: .images)

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                    }
                }

                if let detectedSkinHex, let detectedHairHex {
                    Section("Erkannte Farben") {
                        swatchRow(label: "Hautton", hex: detectedSkinHex)
                        swatchRow(label: "Haarfarbe", hex: detectedHairHex)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Farb-Kalibrierung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { apply() }
                        .disabled(detectedSkinHex == nil)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadAndAnalyze(newItem) }
            }
        }
    }

    private func swatchRow(label: String, hex: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let color = UIColor(hex: hex) {
                Circle().fill(Color(color)).frame(width: 24, height: 24)
            }
            Text(hex)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func loadAndAnalyze(_ item: PhotosPickerItem?) async {
        errorMessage = nil
        detectedSkinHex = nil
        detectedHairHex = nil

        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Foto konnte nicht geladen werden."
            return
        }
        previewImage = image

        guard let result = SkinToneAnalyzer.analyze(image: image) else {
            errorMessage = "Kein Gesicht erkannt — bitte ein Foto mit gut sichtbarem Gesicht wählen."
            return
        }
        detectedSkinHex = result.skin
        detectedHairHex = result.hair
    }

    private func apply() {
        guard let detectedSkinHex else { return }
        profile.skinColorHex = detectedSkinHex
        if let detectedHairHex {
            profile.hairColorHex = detectedHairHex
        }
        dismiss()
    }
}
