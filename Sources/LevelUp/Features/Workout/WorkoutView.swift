import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var newSession: WorkoutSession?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        let session = WorkoutSession()
                        modelContext.insert(session)
                        newSession = session
                    } label: {
                        Label("Training starten", systemImage: "play.fill")
                    }

                    NavigationLink {
                        WeeklyVolumeView()
                    } label: {
                        Label("Wochenauslastung", systemImage: "chart.bar.fill")
                    }
                }

                if !sessions.isEmpty {
                    Section("Letzte Trainings") {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutSessionView(session: session)
            }
            .navigationDestination(item: $newSession) { session in
                WorkoutSessionView(session: session)
            }
        }
    }
}

#Preview {
    WorkoutView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
