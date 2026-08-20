//
//  NextRepApp.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//

import SwiftUI
import SwiftData

@main
struct NextRepApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: [
                Routine.self,
                RoutineExercise.self,
                WorkoutSession.self,
                ExerciseSetRecord.self,
                AMRAPRoundRecord.self
            ]
        )
    }
}
