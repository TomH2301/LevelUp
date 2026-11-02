import SwiftUI
import SceneKit

/// Temporärer Spike-Test für Phase 7.1: prüft, ob SceneKit die aus Blender
/// exportierten USDZ-Shape-Keys als SCNMorpher-Targets lädt. Wird entfernt,
/// sobald der Export-Pfad bestätigt ist.
struct MorphSpikeTestView: View {
    @State private var weight: Double = 0
    @State private var statusText: String = "Lädt…"
    @State private var morphNode: SCNNode?

    private let scene: SCNScene = {
        if let url = Bundle.main.url(forResource: "morphtest", withExtension: "usdz"),
           let loaded = try? SCNScene(url: url) {
            return loaded
        }
        return SCNScene()
    }()

    var body: some View {
        VStack(spacing: 16) {
            SceneView(scene: scene, pointOfView: nil, options: [.allowsCameraControl])
                .frame(height: 320)
                .background(Color.black.opacity(0.05))

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Slider(value: $weight, in: 0...1) {
                Text("Morph-Gewicht")
            }
            .padding(.horizontal)
            .onChange(of: weight) { _, newValue in
                applyWeight(newValue)
            }

            Text("Gewicht: \(weight, specifier: "%.2f")")
                .font(.caption.monospacedDigit())
        }
        .padding()
        .navigationTitle("Spike-Test: Morph")
        .onAppear(perform: setup)
    }

    private func setup() {
        var found: SCNNode?
        scene.rootNode.enumerateHierarchy { node, _ in
            if node.morpher != nil {
                found = node
            }
        }
        morphNode = found

        if let found, let morpher = found.morpher {
            statusText = "Morph-Node gefunden: \(found.name ?? "?") · \(morpher.targets.count) Target(s)"
        } else {
            statusText = "Kein Morpher gefunden — Export-Pfad funktioniert nicht."
        }

        let light = SCNLight()
        light.type = .omni
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(5, 5, 5)
        scene.rootNode.addChildNode(lightNode)
    }

    private func applyWeight(_ value: Double) {
        guard let morpher = morphNode?.morpher, !morpher.targets.isEmpty else { return }
        morpher.setWeight(CGFloat(value), forTargetAt: 0)
    }
}

#Preview {
    MorphSpikeTestView()
}
