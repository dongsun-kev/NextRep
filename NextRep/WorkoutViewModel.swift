//
//  WorkoutViewModel.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//

import Foundation
import SwiftData
import Combine

struct RoutineRestNotice: Equatable {
    let exerciseID: UUID
    let exerciseTitle: String
    let endTime: Date
}

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var state: WorkoutFlowState = .ready
    @Published private(set) var completedSetCounts: [UUID: Int] = [:]
    @Published private(set) var restNotice: RoutineRestNotice?
    @Published private(set) var remainingRestTime: TimeInterval = 0
    @Published private(set) var elapsedSessionTime: TimeInterval = 0
    @Published private(set) var persistenceErrorMessage: String?

    let routine: Routine

    @Published private(set) var workoutSession: WorkoutSession?

    private let modelContext: ModelContext
    private var sessionStartedAt: Date?
    private var timer: Timer?

    init(
        routine: Routine,
        modelContext: ModelContext
    ) {
        self.routine = routine
        self.modelContext = modelContext
    }

    deinit {
        timer?.invalidate()
    }

    var exercises: [RoutineExercise] {
        routine.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var completedSets: Int {
        completedSetCounts.values.reduce(0, +)
    }

    var totalTargetSets: Int {
        exercises.reduce(0) { $0 + max(0, $1.targetSets) }
    }

    var progress: Double {
        guard totalTargetSets > 0 else {
            return 0
        }

        return Double(completedSets) / Double(totalTargetSets)
    }

    func completedSetCount(for exercise: RoutineExercise) -> Int {
        completedSetCounts[exercise.id, default: 0]
    }

    func startWorkout() {
        guard state == .ready,
              !exercises.isEmpty,
              totalTargetSets > 0
        else {
            return
        }

        let session = WorkoutSession(
            mode: .routine,
            routineNameSnapshot: routine.name,
            sourceRoutine: routine
        )

        modelContext.insert(session)

        guard saveContext() else {
            return
        }

        workoutSession = session
        completedSetCounts = Dictionary(
            uniqueKeysWithValues: exercises.map { ($0.id, 0) }
        )
        sessionStartedAt = session.startedAt
        elapsedSessionTime = 0
        state = .exercising

        startTimer()
    }

    func completeNextSet(for exercise: RoutineExercise) {
        guard state == .exercising,
              let session = workoutSession
        else {
            return
        }

        let completedCount = completedSetCount(for: exercise)

        guard completedCount < exercise.targetSets else {
            return
        }

        let now = Date.now
        let record = ExerciseSetRecord(
            routineExerciseID: exercise.id,
            exerciseType: exercise.exerciseType,
            setNumber: completedCount + 1,
            plannedReps: exercise.targetReps,
            actualReps: exercise.targetReps,
            duration: 0,
            completedAt: now
        )

        session.setRecords.append(record)

        guard saveContext() else {
            return
        }

        completedSetCounts[exercise.id] = completedCount + 1

        if completedSets >= totalTargetSets {
            dismissRestNotice()
            stopTimer()
            state = .sessionReview
        } else {
            showRestNotice(for: exercise, from: now)
        }
    }

    func undoLastSet(for exercise: RoutineExercise) {
        guard state == .exercising,
              let session = workoutSession,
              let record = session.setRecords
                .filter({ $0.routineExerciseID == exercise.id })
                .max(by: { $0.setNumber < $1.setNumber })
        else {
            return
        }

        session.setRecords.removeAll { $0.id == record.id }
        modelContext.delete(record)

        guard saveContext() else {
            return
        }

        completedSetCounts[exercise.id] = max(
            0,
            completedSetCount(for: exercise) - 1
        )
    }

    func dismissRestNotice() {
        restNotice = nil
        remainingRestTime = 0
    }

    func editCompletedSets() {
        guard state == .sessionReview else {
            return
        }

        state = .exercising
        startTimer()
    }

    func completeWorkout() {
        guard state == .sessionReview,
              let session = workoutSession
        else {
            return
        }

        session.endedAt = .now
        session.completionStatus = .completed
        session.interruptionReason = nil

        guard saveContext() else {
            return
        }

        stopTimer()
        state = .completed
    }

    func interruptWorkout(reason: InterruptionReason) {
        guard state == .exercising || state == .sessionReview,
              let session = workoutSession
        else {
            return
        }

        session.endedAt = .now
        session.completionStatus = .interrupted
        session.interruptionReason = reason

        guard saveContext() else {
            return
        }

        stopTimer()
        dismissRestNotice()
        state = .interrupted
    }

    func cleanup() {
        stopTimer()
    }

    private func showRestNotice(
        for exercise: RoutineExercise,
        from startTime: Date
    ) {
        let restDuration = max(0, exercise.targetRestDuration)

        guard restDuration > 0 else {
            dismissRestNotice()
            return
        }

        restNotice = RoutineRestNotice(
            exerciseID: exercise.id,
            exerciseTitle: exercise.exerciseType.title,
            endTime: startTime.addingTimeInterval(restDuration)
        )
        remainingRestTime = restDuration
    }

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.25,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTime()
            }
        }
    }

    private func updateTime() {
        let now = Date.now

        if let sessionStartedAt {
            elapsedSessionTime = now.timeIntervalSince(sessionStartedAt)
        }

        if let restNotice {
            let remaining = restNotice.endTime.timeIntervalSince(now)
            remainingRestTime = max(0, remaining)

            if remaining <= 0 {
                dismissRestNotice()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @discardableResult
    private func saveContext() -> Bool {
        guard modelContext.hasChanges else {
            return true
        }

        do {
            try modelContext.save()
            persistenceErrorMessage = nil
            return true
        } catch {
            persistenceErrorMessage = error.localizedDescription
            modelContext.rollback()
            print("SwiftData 저장 실패:", error)
            return false
        }
    }
}
