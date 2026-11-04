import SwiftUI
import SceneKit
import SwiftData

struct AvatarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AvatarProfile]
    @Query(sort: \BodyMetricEntry.date, order: .reverse) private var bodyMetrics: [BodyMetricEntry]

    @State private var scene = SCNScene()
    @State private var frontCameraNode: SCNNode?
    @State private var backCameraNode: SCNNode?
    @State private var bodyNode: SCNNode?
    @State private var underwearNode: SCNNode?
    @State private var hairNode: SCNNode?
    @State private var braNode: SCNNode?
    @State private var eyesNode: SCNNode?
    @State private var isCalibratingPhoto = false
    @State private var isEditingBasicData = false
    @State private var statusText: String = "Lädt…"

    private var profile: AvatarProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Vorne/Rücken gleichzeitig nebeneinander statt Umschalt-
                // Picker — und keine freie Kamerasteuerung (kein Zoom/Pan/
                // Rotieren), bewusst nur die zwei festen Ansichten.
                HStack(spacing: 1) {
                    avatarSceneView(title: "Vorne", camera: frontCameraNode)
                    avatarSceneView(title: "Rücken", camera: backCameraNode)
                }
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

    private func avatarSceneView(title: String, camera: SCNNode?) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            SceneView(scene: scene, pointOfView: camera, options: [])
        }
    }

    /// Lädt Körper, Unterwäsche, Haare (und BH bei Frauen) aus unserem
    /// eigenen Binärformat (siehe BinaryMeshLoader.swift / BlenderAssets/
    /// build_character_mh.py) statt aus USDZ — das garantiert Vertex-
    /// Übereinstimmung zwischen Basis und Fat/Muscular-Targets durch den
    /// Aufbau selbst, statt sich auf Apples USD-Importer zu verlassen (der
    /// mehrere unabhängig importierte Dateien nicht zuverlässig identisch
    /// indiziert — das hat am Gerät zur Kopf-Explosion geführt). Augen
    /// morphen nicht mit, bleiben daher normale USDZ-Objekte.
    private func loadScene() {
        guard let profile else {
            statusText = "Kein Avatar-Profil."
            return
        }
        let prefix = profile.gender == .female ? "LevelUp_Female" : "LevelUp_Male"

        guard let body = loadBodyPart(prefix: "\(prefix)_Body"),
              let underwear = loadBodyPart(prefix: "\(prefix)_Underwear"),
              let hair = loadBodyPart(prefix: "\(prefix)_Hair") else {
            statusText = "Konnte eine der \(prefix)-Dateien nicht laden."
            return
        }
        let bra = profile.gender == .female ? loadBodyPart(prefix: "\(prefix)_Bra") : nil
        let eyes = loadEyes(prefix: prefix)

        let newScene = SCNScene()

        // Blender ist Z-up, SceneKit/USD-Konvention ist Y-up. Der alte
        // USDZ-Export hat diese Umrechnung automatisch miterledigt; unser
        // eigenes Binärformat (BinaryMeshLoader) gibt die rohen Blender-
        // Koordinaten unverändert weiter, deshalb drehen wir hier einmalig
        // um -90° um die X-Achse (Blender Z→SceneKit Y, Blender Y→SceneKit
        // -Z). Ohne das lag der Avatar quasi "auf dem Rücken" — die
        // Vorne-Kamera blickte von oben auf den Kopf statt von vorne.
        let avatarRoot = SCNNode()
        avatarRoot.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        avatarRoot.addChildNode(body)
        avatarRoot.addChildNode(underwear)
        avatarRoot.addChildNode(hair)
        if let bra { avatarRoot.addChildNode(bra) }
        if let eyes { avatarRoot.addChildNode(eyes) }
        newScene.rootNode.addChildNode(avatarRoot)

        setupLighting(in: newScene)
        let (front, back) = setupCameras(in: newScene, target: avatarRoot)

        scene = newScene
        bodyNode = body
        underwearNode = underwear
        hairNode = hair
        braNode = bra
        eyesNode = eyes
        frontCameraNode = front
        backCameraNode = back
        statusText = "Vertices: \(body.geometry?.sources.first?.vectorCount ?? 0)"

        updateMorphWeights()
        applyMaterials()
    }

    /// Lädt Basis + Fat/Muscular-Morph-Targets für einen Körperteil aus dem
    /// Binärformat und baut daraus einen Node mit eigenem Morpher.
    /// Target-Reihenfolge: Fat(0), Muscular(1).
    private func loadBodyPart(prefix: String) -> SCNNode? {
        guard let base = BinaryMeshLoader.loadMesh(named: prefix) else { return nil }

        let fat = BinaryMeshLoader.loadMorphTarget(named: prefix, shape: "Fat", vertexCount: base.vertexCount)
        let muscular = BinaryMeshLoader.loadMorphTarget(named: prefix, shape: "Muscular", vertexCount: base.vertexCount)
        let targets = [fat, muscular].compactMap { $0 }

        let node = SCNNode(geometry: base.geometry)
        if targets.count == 2 {
            let morpher = SCNMorpher()
            morpher.targets = targets
            // .additive, not .normalized: Fat/Muscular are independent,
            // stackable axes. In .normalized mode they competed for a
            // shared weight budget — increasing KFA visibly shrank the
            // Muscular contribution and the figure looked THINNER as fat
            // went up.
            morpher.calculationMode = .additive
            node.morpher = morpher
        }
        return node
    }

    /// Augen morphen nicht mit Fat/Muscular (Augengröße bleibt konstant),
    /// bleiben also ein ganz normal über USDZ geladenes, statisches Objekt
    /// — kein Korrespondenz-Risiko, weil nichts mit ihnen abgeglichen
    /// werden muss.
    private func loadEyes(prefix: String) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "\(prefix)_Eyes", withExtension: "usdz"),
              let loaded = try? SCNScene(url: url) else { return nil }
        return loaded.rootNode
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

    /// Baut zwei feste Kameras (Vorne/Rücken) statt einer frei drehbaren. Die
    /// Distanz basiert auf der UNGEMORPHTEN Basis-Hülle (Gewichte sind beim
    /// Scene-Aufbau noch 0) mit großzügigem Rand, damit auch die stärkste
    /// Fat/Muscular-Ausprägung noch vollständig ins Bild passt.
    private func setupCameras(in scene: SCNScene, target: SCNNode) -> (front: SCNNode, back: SCNNode) {
        let (localCenter, radius) = target.boundingSphere
        let worldCenter = target.convertPosition(localCenter, to: nil)
        // Jede der beiden Split-Screen-Hälften ist nur noch halb so breit
        // wie vorher die Vollbild-Ansicht — bei gleichbleibendem Kamera-
        // Blickwinkel würde das die ausgestreckten T-Pose-Arme seitlich
        // abschneiden, daher mehr Abstand als vorher (3.4 → 4.6).
        let distance = max(radius * 4.6, 0.8)

        let front = SCNNode()
        front.camera = SCNCamera()
        front.position = SCNVector3(worldCenter.x, worldCenter.y, worldCenter.z + distance)
        front.look(at: worldCenter)
        scene.rootNode.addChildNode(front)

        let back = SCNNode()
        back.camera = SCNCamera()
        back.position = SCNVector3(worldCenter.x, worldCenter.y, worldCenter.z - distance)
        back.look(at: worldCenter)
        scene.rootNode.addChildNode(back)

        return (front, back)
    }

    /// Beide Achsen sind rein aus deinen echten Körperdaten abgeleitet — nicht
    /// manuell einstellbar. Körperfett kommt von einem echten Messwert, sobald
    /// einer existiert, sonst aus der Deurenberg-Schätzung (Größe/Gewicht/
    /// Alter/Geschlecht). Muscular kommt direkt aus der daraus berechneten
    /// fettfreien Masse (Gewicht × (1 − KFA/100), auf die Größe normalisiert)
    /// — kein Kraft-Level, keine manuelle Mischung. Dieselben Gewichte gelten
    /// für Körper, Unterwäsche und Haare, damit alle drei synchron mitwachsen.
    private func updateMorphWeights() {
        guard let profile else { return }

        let weightKg = bodyMetrics.first?.weightKg ?? profile.fallbackWeightKg
        let kfa = bodyMetrics.first?.bodyFatPercentage ?? BodyCompositionEstimator.estimatedBodyFatPercent(
            heightCm: profile.heightCm, weightKg: weightKg, age: profile.age, gender: profile.gender
        )
        let fatWeight = normalized(kfa, min: 6, max: 35)

        let leanIndex = BodyCompositionEstimator.leanMassIndex(weightKg: weightKg, bodyFatPercent: kfa, heightCm: profile.heightCm)
        let muscleWeight = normalized(leanIndex, min: 16, max: 26)

        for node in [bodyNode, underwearNode, hairNode, braNode] {
            guard let morpher = node?.morpher, morpher.targets.count >= 2 else { continue }
            morpher.setWeight(CGFloat(fatWeight), forTargetAt: 0)
            morpher.setWeight(CGFloat(muscleWeight), forTargetAt: 1)
        }
    }

    private func applyMaterials() {
        guard let profile else { return }
        applyColor(profile.skinColorHex, to: bodyNode)
        applyColor("#262529", to: underwearNode)
        applyColor("#262529", to: braNode)
        applyColor(profile.hairColorHex, to: hairNode)
        applyEyeColors()
    }

    /// Lederhaut (weiß) und Iris (fest bräunlich, keine Nutzereinstellung) —
    /// Augen sind zwei Objekte pro Seite (sclera + iris), erkennbar am
    /// Node-Namen aus BlenderAssets/build_character_mh.py's add_eyeball().
    private func applyEyeColors() {
        guard let eyesNode else { return }
        eyesNode.enumerateHierarchy { node, _ in
            guard let name = node.name, node.geometry != nil else { return }
            if name.contains("iris") {
                applyColor("#40291A", to: node)
            } else if name.contains("sclera") {
                applyColor("#EBE8E0", to: node)
            }
        }
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
