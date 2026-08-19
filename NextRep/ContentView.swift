//
//  ContentView.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//

import SwiftUI

struct ContentView: View {
    private let routine: Routine

    init(routine: Routine = .sample) {
        self.routine = routine
    }

    var body: some View {
        WorkoutView(routine: routine)
    }
}

private extension Routine {
    static var sample: Routine {
        Routine(
            name: "상체 기본 루틴",
            exercises: [
                RoutineExercise(
                    exerciseType: .pushUp,
                    orderIndex: 0,
                    targetSets: 3,
                    targetReps: 10,
                    targetRestDuration: 30
                ),
                RoutineExercise(
                    exerciseType: .pullUp,
                    orderIndex: 1,
                    targetSets: 3,
                    targetReps: 5,
                    targetRestDuration: 30
                )
            ]
        )
    }
}

#Preview {
    ContentView()
}
