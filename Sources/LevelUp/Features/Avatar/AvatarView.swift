import SwiftUI
import SceneKit
import SwiftData

struct AvatarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AvatarProfile]
    @Query(sort: \BodyMetricEntry.date, order: .reverse) private var bodyMetrics: [BodyMetricEntry]
    @Query private var sessions: [WorkoutSession]

    @State private var scene = SCNScene()
    @State private var cameraNode: SCNNode?
    @State private var morphNode: SCNNode?
    @State private var isCalibratingPhoto = false
    @State private var statusText: String = "Lädt…"

    private var profile: AvatarProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SceneView(scene: scene, pointOfView: cameraNode, options: [.allowsCameraControl])
                    .frame(maxHeight: .infinity)
                    .background(Color.black.opacity(0.05))

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                if let profile {
                    Picker("Geschlecht", selection: Binding(
                        get: { profile.gender },
                        set: { newValue in
                            profile.gender = newValue
                            loadScene()
                        }
                    )) {
                        ForEach(AvatarGender.allCases) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
            }
            .navigationTitle("Avatar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCalibratingPhoto = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $isCalibratingPhoto) {
                if let profile {
                    PhotoCalibrationView(profile: profile)
                        .onDisappear { applySkinTone() }
                }
            }
            .task {
                ensureProfile()
                loadScene()
            }
        }
    }

    private func ensureProfile() {
        if profiles.isEmpty {
            modelContext.insert(AvatarProfile())
        }
    }

    private func loadScene() {
        guard let profile else {
            statusText = "Kein Avatar-Profil."
            return
        }
        let resourceName = profile.gender == .female ? "LevelUp_Female" : "LevelUp_Male"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "usdz") else {
            statusText = "Datei \(resourceName).usdz nicht im App-Bundle gefunden."
            return
        }

        let loaded: SCNScene
        do {
            loaded = try SCNScene(url: url)
        } catch {
            statusText = "SCNScene-Ladefehler: \(error.localizedDescription)"
            return
        }

        var found: SCNNode?
        var meshCount = 0
        loaded.rootNode.enumerateHierarchy { node, _ in
            if node.geometry != nil { meshCount += 1 }
            if node.morpher != nil { found = node }
        }

        setupLighting(in: loaded)
        let (camera, cameraInfo) = setupCamera(in: loaded, target: found)

        scene = loaded
        morphNode = found
        cameraNode = camera

        let morphInfo = found != nil ? "Morpher: \(found?.morpher?.targets.count ?? 0) Target(s)" : "Kein Morpher gefunden"
        statusText = "Meshes: \(meshCount) · \(morphInfo) · \(cameraInfo)"

        updateMorphWeights()
        applySkinTone()
    }

    private func setupLighting(in scene: SCNScene) {
        let key = SCNLight()
        key.type = .directional
        key.intensity = 800
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 400
        ambient.color = UIColor(white: 0.9, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    /// Kamera-Distanz aus der tatsächlichen Bounding-Sphere des Ziel-Nodes berechnet
    /// (skalierungsunabhängig) statt aus einer angenommenen "Meter"-Größe, die sich
    /// beim Export als falsch herausgestellt hat.
    private func setupCamera(in scene: SCNScene, target: SCNNode?) -> (SCNNode, String) {
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera

        guard let target else {
            cameraNode.position = SCNVector3(0, 1, 3)
            cameraNode.look(at: SCNVector3(0, 1, 0))
            scene.rootNode.addChildNode(cameraNode)
            return (cameraNode, "kein Ziel-Node für Kamera")
        }

        let (localCenter, radius) = target.boundingSphere
        let worldCenter = target.convertPosition(localCenter, to: nil)
        let distance = max(radius * 3, 0.01)

        cameraNode.position = SCNVector3(worldCenter.x, worldCenter.y, worldCenter.z + distance)
        cameraNode.look(at: worldCenter)
        scene.rootNode.addChildNode(cameraNode)

        let info = String(
            format: "center=(%.3f, %.3f, %.3f) radius=%.4f",
            worldCenter.x, worldCenter.y, worldCenter.z, radius
        )
        return (cameraNode, info)
    }

    private func updateMorphWeights() {
        guard let profile, let morpher = morphNode?.morpher, morpher.targets.count >= 2 else { return }

        let kfa = bodyMetrics.first?.bodyFatPercentage ?? profile.minBodyFatPercent
        let fatWeight = normalized(kfa, min: profile.minBodyFatPercent, max: profile.maxBodyFatPercent)

        let strengthXP = SkillXPCalculator.strengthXP(sessions: sessions)
        let strengthLevel = LevelCalculator.level(forXP: strengthXP)
        let muscleWeight = normalized(Double(strengthLevel), min: 1, max: Double(profile.maxStrengthLevel))

        morpher.setWeight(CGFloat(fatWeight), forTargetAt: 0)
        morpher.setWeight(CGFloat(muscleWeight), forTargetAt: 1)
    }

    private func applySkinTone() {
        guard let profile, let color = UIColor(hex: profile.skinColorHex) else { return }
        morphNode?.geometry?.materials.forEach { $0.diffuse.contents = color }
    }

    private func normalized(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        guard maxValue > minValue else { return 0 }
        return Swift.min(Swift.max((value - minValue) / (maxValue - minValue), 0), 1)
    }
}

#Preview {
    AvatarView()
        .modelContainer(for: [AvatarProfile.self, BodyMetricEntry.self, WorkoutSession.self], inMemory: true)
}
