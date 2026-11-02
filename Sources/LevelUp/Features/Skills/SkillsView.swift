import SwiftUI
import SwiftData

struct SkillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \ActivityLog.date, order: .reverse) private var logs: [ActivityLog]
    @State private var isLoggingActivity = false

    private var xpBySkill: [Skill: Double] {
        [
            .strength: SkillXPCalculator.strengthXP(sessions: sessions),
            .mind: SkillXPCalculator.xp(for: .reading, logs: logs),
            .agility: SkillXPCalculator.xp(for: .stretching, logs: logs),
            .endurance: SkillXPCalculator.xp(for: .cardio, logs: logs)
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Skill.allCases) { skill in
                        SkillRow(skill: skill, xp: xpBySkill[skill] ?? 0)
                    }
                }

                Section {
                    Button {
                        isLoggingActivity = true
                    } label: {
                        Label("Aktivität loggen", systemImage: "plus")
                    }
                } footer: {
                    Text("Kraft-XP kommt automatisch aus deinen Workout-Sätzen. Lesen, Stretching und Cardio trägst du hier ein.")
                }

                if !logs.isEmpty {
                    Section("Verlauf") {
                        ForEach(logs) { log in
                            HStack {
                                Label(log.type.rawValue, systemImage: log.type.icon)
                                Spacer()
                                Text("\(log.minutes) Min · \(log.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: deleteLogs)
                    }
                }
            }
            .navigationTitle("Skills")
            .sheet(isPresented: $isLoggingActivity) {
                AddActivityView()
            }
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(logs[index])
        }
    }
}

private struct SkillRow: View {
    let skill: Skill
    let xp: Double

    private var progress: (level: Int, currentLevelXP: Double, nextLevelXP: Double) {
        LevelCalculator.progress(forXP: xp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(skill.rawValue, systemImage: skill.icon)
                    .font(.headline)
                Spacer()
                Text("Level \(progress.level)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
            }
            ProgressView(value: progress.nextLevelXP > 0 ? progress.currentLevelXP / progress.nextLevelXP : 0)
            Text("\(Int(progress.currentLevelXP)) / \(Int(progress.nextLevelXP)) XP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SkillsView()
        .modelContainer(for: [WorkoutSession.self, ActivityLog.self], inMemory: true)
}
