import SwiftUI
import SceneKit
import SwiftData

struct AvatarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AvatarProfile]
    @Query(sort: \BodyMetricEntry.date, order: .reverse) private var bodyMetrics: [BodyMetricEntry]
    @Query private var sessions: [WorkoutSession]

    @State private var scene = SCNScene()
    @State private var morphNode: SCNNode?

    private var profile: AvatarProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SceneView(scene: scene, pointOfView: nil, options: [.allowsCameraControl])
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

        let light = SCNLight()
        light.type = .omni
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(3, 5, 5)
        loaded.rootNode.addChildNode(lightNode)

        scene = loaded
        morphNode = found
        updateMorphWeights()
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

    private func normalized(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        guard maxValue > minValue else { return 0 }
        return Swift.min(Swift.max((value - minValue) / (maxValue - minValue), 0), 1)
    }
}

#Preview {
    AvatarView()
        .modelContainer(for: [AvatarProfile.self, BodyMetricEntry.self, WorkoutSession.self], inMemory: true)
}
