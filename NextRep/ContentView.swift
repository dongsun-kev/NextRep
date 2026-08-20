//
//  ContentView.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]

    @AppStorage("hasSeededInitialRoutine") private var hasSeededInitialRoutine = false
    @State private var seedErrorMessage: String?

    var body: some View {
        TabView {
            RoutineLibraryView()
                .tabItem {
                    Label("일반 루틴", systemImage: "list.bullet.clipboard")
                }

            NavigationStack {
                AMRAPView(modelContext: modelContext)
                    .navigationTitle("Challenge")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Challenge", systemImage: "timer")
            }

            TodayHistoryView()
                .tabItem {
                    Label("오늘 기록", systemImage: "calendar")
                }
        }
        .task {
            seedSampleRoutineIfNeeded()
        }
        .alert(
            "초기 루틴를 준비하지 못했습니다",
            isPresented: Binding(
                get: { seedErrorMessage != nil },
                set: { if !$0 { seedErrorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(seedErrorMessage ?? "")
        }
    }

    private func seedSampleRoutineIfNeeded() {
        guard !hasSeededInitialRoutine else {
            return
        }

        if routines.contains(where: { $0.id == SampleRoutine.id }) {
            hasSeededInitialRoutine = true
            return
        }

        modelContext.insert(SampleRoutine.make())

        do {
            try modelContext.save()
            hasSeededInitialRoutine = true
        } catch {
            modelContext.rollback()
            seedErrorMessage = error.localizedDescription
        }
    }
}

private enum SampleRoutine {
    static let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static func make() -> Routine {
        Routine(
            id: id,
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
        .modelContainer(
            for: [
                Routine.self,
                RoutineExercise.self,
                WorkoutSession.self,
                ExerciseSetRecord.self,
                AMRAPRoundRecord.self
            ],
            inMemory: true
        )
}
