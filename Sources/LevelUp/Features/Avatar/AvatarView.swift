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
    @State private var bodyNode: SCNNode?
    @State private var isCalibratingPhoto = false
    @State private var isEditingBasicData = false
    @State private var statusText: String = "Lädt…"

    private var profile: AvatarProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SceneView(scene: scene, pointOfView: cameraNode, options: [.allowsCameraControl])
                    .frame(maxHeight: .infinity)

                Text(statusText)
                    .font(.caption2)
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
                        isEditingBasicData = true
                    } label: {
                        Image(systemName: "ruler")
                    }
                }
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
            .sheet(isPresented: $isEditingBasicData) {
                if let profile {
                    BasicDataView(profile: profile)
                        .onDisappear { updateMorphWeights() }
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

    /// Lädt Basis/Fat/Muscular als drei SEPARATE, nicht-skelettgebundene Meshes
    /// (siehe BlenderAssets/build_character.py) und baut den SCNMorpher selbst
    /// zusammen, statt ihn aus einer USD-Skelett-Struktur zu übernehmen — die
    /// hat sich in SceneKit als unzuverlässig erwiesen (Mesh wurde verzerrt).
    private func loadScene() {
        guard let profile else {
            statusText = "Kein Avatar-Profil."
            return
        }
        let prefix = profile.gender == .female ? "LevelUp_Female" : "LevelUp_Male"

        guard let baseGeometry = loadGeometry(named: "\(prefix)_Basis"),
              let fatGeometry = loadGeometry(named: "\(prefix)_Fat"),
              let muscularGeometry = loadGeometry(named: "\(prefix)_Muscular") else {
            statusText = "Konnte eine der drei \(prefix)-Dateien nicht laden."
            return
        }

        let morpher = SCNMorpher()
        morpher.targets = [fatGeometry, muscularGeometry]
        morpher.calculationMode = .normalized

        let node = SCNNode(geometry: baseGeometry)
        node.morpher = morpher

        let newScene = SCNScene()
        newScene.rootNode.addChildNode(node)
        setupLighting(in: newScene)
        let camera = setupCamera(in: newScene, target: node)

        scene = newScene
        bodyNode = node
        cameraNode = camera
        statusText = "Vertices: \(baseGeometry.sources.first?.vectorCount ?? 0)"

        updateMorphWeights()
        applySkinTone()
    }

    private func loadGeometry(named name: String) -> SCNGeometry? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz"),
              let loaded = try? SCNScene(url: url) else { return nil }
        var geometry: SCNGeometry?
        loaded.rootNode.enumerateHierarchy { node, _ in
            if geometry == nil, let g = node.geometry {
                geometry = g
            }
        }
        return geometry
    }

    private func setupLighting(in scene: SCNScene) {
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1000
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 400
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
    }

    private func setupCamera(in scene: SCNScene, target: SCNNode) -> SCNNode {
        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera

        let (localCenter, radius) = target.boundingSphere
        let worldCenter = target.convertPosition(localCenter, to: nil)
        let distance = max(radius * 2.6, 0.5)

        cameraNode.position = SCNVector3(worldCenter.x, worldCenter.y, worldCenter.z + distance)
        cameraNode.look(at: worldCenter)
        scene.rootNode.addChildNode(cameraNode)
        return cameraNode
    }

    /// Körperfett kommt von einem echten Messwert, sobald einer existiert — sonst
    /// aus der Deurenberg-Schätzung (Größe/Gewicht/Alter/Geschlecht). Dasselbe gilt
    /// fürs Gewicht: geloggter Wert aus dem Körper-Tab schlägt den Onboarding-Fallback.
    /// Muscular mischt einen Fettfreie-Masse-Proxy (sofort verfügbar) mit dem
    /// trainingsbasierten Kraft-Level (baut sich über Zeit auf).
    private func updateMorphWeights() {
        guard let profile, let morpher = bodyNode?.morpher, morpher.targets.count >= 2 else { return }

        let weightKg = bodyMetrics.first?.weightKg ?? profile.fallbackWeightKg
        let kfa = bodyMetrics.first?.bodyFatPercentage ?? BodyCompositionEstimator.estimatedBodyFatPercent(
            heightCm: profile.heightCm, weightKg: weightKg, age: profile.age, gender: profile.gender
        )
        let fatWeight = normalized(kfa, min: profile.minBodyFatPercent, max: profile.maxBodyFatPercent)

        let leanIndex = BodyCompositionEstimator.leanMassIndex(weightKg: weightKg, bodyFatPercent: kfa, heightCm: profile.heightCm)
        let leanWeight = normalized(leanIndex, min: profile.minLeanMassIndex, max: profile.maxLeanMassIndex)

        let strengthXP = SkillXPCalculator.strengthXP(sessions: sessions)
        let strengthLevel = LevelCalculator.level(forXP: strengthXP)
        let trainingWeight = normalized(Double(strengthLevel), min: 1, max: Double(profile.maxStrengthLevel))

        let muscleWeight = leanWeight * (1 - profile.trainingInfluence) + trainingWeight * profile.trainingInfluence

        morpher.setWeight(CGFloat(fatWeight), forTargetAt: 0)
        morpher.setWeight(CGFloat(muscleWeight), forTargetAt: 1)
    }

    private func applySkinTone() {
        guard let profile, let color = UIColor(hex: profile.skinColorHex) else { return }
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = color
        material.isDoubleSided = true
        bodyNode?.geometry?.materials = [material]
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
