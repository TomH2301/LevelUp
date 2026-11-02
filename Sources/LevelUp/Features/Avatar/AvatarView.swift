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

    private var profile: AvatarProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SceneView(scene: scene, pointOfView: cameraNode, options: [.allowsCameraControl])
                    .frame(maxHeight: .infinity)
                    .background(Color.black.opacity(0.05))

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
        guard let profile else { return }
        let resourceName = profile.gender == .female ? "LevelUp_Female" : "LevelUp_Male"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "usdz"),
              let loaded = try? SCNScene(url: url) else { return }

        var found: SCNNode?
        loaded.rootNode.enumerateHierarchy { node, _ in
            if node.morpher != nil { found = node }
        }

        setupLighting(in: loaded)
        let camera = setupCamera(in: loaded, framing: found ?? loaded.rootNode)

        scene = loaded
        morphNode = found
        cameraNode = camera

        updateMorphWeights()
        applySkinTone()
    }

    private func setupLighting(in scene: SCNScene) {
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1100
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 350
        ambient.color = UIColor(white: 0.9, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    private func setupCamera(in scene: SCNScene, framing node: SCNNode) -> SCNNode {
        let (minVec, maxVec) = node.boundingBox
        let height = max(CGFloat(maxVec.y - minVec.y), 1)
        let centerY = CGFloat(maxVec.y + minVec.y) / 2

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, Float(centerY), Float(height) * 2.0)
        cameraNode.look(at: SCNVector3(0, Float(centerY), 0))
        scene.rootNode.addChildNode(cameraNode)
        return cameraNode
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
