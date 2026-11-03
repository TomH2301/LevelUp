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
    @State private var underwearNode: SCNNode?
    @State private var hairNode: SCNNode?
    @State private var isCalibratingPhoto = false
    @State private var isEditingBasicData = false
    @State private var isEditingCalibration = false
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditingCalibration = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $isCalibratingPhoto) {
                if let profile {
                    PhotoCalibrationView(profile: profile)
                        .onDisappear {
                            applyMaterials()
                            updateMorphWeights()
                        }
                }
            }
            .sheet(isPresented: $isEditingBasicData) {
                if let profile {
                    BasicDataView(profile: profile)
                        .onDisappear { updateMorphWeights() }
                }
            }
            .sheet(isPresented: $isEditingCalibration) {
                if let profile {
                    AvatarCalibrationView(profile: profile)
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

    /// Lädt Körper, Unterwäsche und Haare je als drei SEPARATE, nicht-skelett-
    /// gebundene Meshes (siehe BlenderAssets/build_character.py) und baut für
    /// jeden Teil einen eigenen SCNMorpher selbst zusammen, statt ihn aus einer
    /// USD-Skelett-Struktur zu übernehmen — die hat sich in SceneKit als
    /// unzuverlässig erwiesen (Mesh wurde verzerrt).
    private func loadScene() {
        guard let profile else {
            statusText = "Kein Avatar-Profil."
            return
        }
        let prefix = profile.gender == .female ? "LevelUp_Female" : "LevelUp_Male"

        guard let body = loadBodyPart(prefix: prefix, extraTargets: ["FaceWide"]),
              let underwear = loadBodyPart(prefix: "\(prefix)_Underwear"),
              let hair = loadBodyPart(prefix: "\(prefix)_Hair") else {
            statusText = "Konnte eine der \(prefix)-Dateien nicht laden."
            return
        }

        let newScene = SCNScene()
        newScene.rootNode.addChildNode(body)
        newScene.rootNode.addChildNode(underwear)
        newScene.rootNode.addChildNode(hair)
        setupLighting(in: newScene)
        let camera = setupCamera(in: newScene, target: body)

        scene = newScene
        bodyNode = body
        underwearNode = underwear
        hairNode = hair
        cameraNode = camera
        statusText = "Vertices: \(body.geometry?.sources.first?.vectorCount ?? 0)"

        updateMorphWeights()
        applyMaterials()
    }

    /// Lädt Basis/Fat/Muscular (+ optionale Zusatz-Targets wie FaceWide) für
    /// einen Körperteil und baut daraus einen Node mit eigenem Morpher.
    /// Reihenfolge der Targets: Fat(0), Muscular(1), dann extraTargets in
    /// angegebener Reihenfolge ab Index 2.
    private func loadBodyPart(prefix: String, extraTargets: [String] = []) -> SCNNode? {
        guard let baseGeometry = loadGeometry(named: "\(prefix)_Basis"),
              let fatGeometry = loadGeometry(named: "\(prefix)_Fat"),
              let muscularGeometry = loadGeometry(named: "\(prefix)_Muscular") else {
            return nil
        }

        var targets = [fatGeometry, muscularGeometry]
        for extra in extraTargets {
            if let geometry = loadGeometry(named: "\(prefix)_\(extra)") {
                targets.append(geometry)
            }
        }

        let morpher = SCNMorpher()
        morpher.targets = targets
        morpher.calculationMode = .normalized

        let node = SCNNode(geometry: baseGeometry)
        node.morpher = morpher
        return node
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
    /// trainingsbasierten Kraft-Level (baut sich über Zeit auf). Dieselben beiden
    /// Gewichte gelten für Körper, Unterwäsche und Haare gleichermaßen, damit alle
    /// drei Teile synchron mitwachsen.
    private func updateMorphWeights() {
        guard let profile else { return }

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

        for node in [bodyNode, underwearNode, hairNode] {
            guard let morpher = node?.morpher, morpher.targets.count >= 2 else { continue }
            morpher.setWeight(CGFloat(fatWeight), forTargetAt: 0)
            morpher.setWeight(CGFloat(muscleWeight), forTargetAt: 1)
        }

        // FaceWide (Index 2) nur am Körper vorhanden — einmalig aus der
        // Foto-Kalibrierung, nicht aus Tracking-Daten wie Fat/Muscular.
        if let morpher = bodyNode?.morpher, morpher.targets.count >= 3 {
            morpher.setWeight(CGFloat(profile.faceWidthWeight), forTargetAt: 2)
        }
    }

    private func applyMaterials() {
        guard let profile else { return }
        applyColor(profile.skinColorHex, to: bodyNode)
        applyColor("#262529", to: underwearNode)
        applyColor(profile.hairColorHex, to: hairNode)
    }

    private func applyColor(_ hex: String, to node: SCNNode?) {
        guard let color = UIColor(hex: hex) else { return }
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = color
        material.isDoubleSided = true
        node?.geometry?.materials = [material]
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
