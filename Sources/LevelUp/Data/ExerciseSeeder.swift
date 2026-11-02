import SwiftData

enum ExerciseSeeder {
    static func seed(into context: ModelContext) {
        let exercises = [
            Exercise(name: "Bankdrücken", muscleEngagements: [
                MuscleEngagement(muscleGroup: .chest, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .triceps, setFactor: 0.5),
                MuscleEngagement(muscleGroup: .frontDelts, setFactor: 0.5)
            ]),
            Exercise(name: "Kniebeuge", muscleEngagements: [
                MuscleEngagement(muscleGroup: .quads, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .glutes, setFactor: 0.5),
                MuscleEngagement(muscleGroup: .hamstrings, setFactor: 0.3)
            ]),
            Exercise(name: "Kreuzheben", muscleEngagements: [
                MuscleEngagement(muscleGroup: .back, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .hamstrings, setFactor: 0.7),
                MuscleEngagement(muscleGroup: .glutes, setFactor: 0.5)
            ]),
            Exercise(name: "Schulterdrücken", muscleEngagements: [
                MuscleEngagement(muscleGroup: .frontDelts, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .sideDelts, setFactor: 0.5),
                MuscleEngagement(muscleGroup: .triceps, setFactor: 0.3)
            ]),
            Exercise(name: "Latzug", muscleEngagements: [
                MuscleEngagement(muscleGroup: .back, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .biceps, setFactor: 0.5)
            ]),
            Exercise(name: "Rudern (vorgebeugt)", muscleEngagements: [
                MuscleEngagement(muscleGroup: .back, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .rearDelts, setFactor: 0.3),
                MuscleEngagement(muscleGroup: .biceps, setFactor: 0.3)
            ]),
            Exercise(name: "Bizepscurls", muscleEngagements: [
                MuscleEngagement(muscleGroup: .biceps, setFactor: 1.0)
            ]),
            Exercise(name: "Trizepsdrücken", muscleEngagements: [
                MuscleEngagement(muscleGroup: .triceps, setFactor: 1.0)
            ]),
            Exercise(name: "Beinpresse", muscleEngagements: [
                MuscleEngagement(muscleGroup: .quads, setFactor: 1.0),
                MuscleEngagement(muscleGroup: .glutes, setFactor: 0.4)
            ]),
            Exercise(name: "Wadenheben", muscleEngagements: [
                MuscleEngagement(muscleGroup: .calves, setFactor: 1.0)
            ]),
            Exercise(name: "Crunches", muscleEngagements: [
                MuscleEngagement(muscleGroup: .core, setFactor: 1.0)
            ]),
            Exercise(name: "Seitheben", muscleEngagements: [
                MuscleEngagement(muscleGroup: .sideDelts, setFactor: 1.0)
            ])
        ]

        for exercise in exercises {
            context.insert(exercise)
        }
    }
}
