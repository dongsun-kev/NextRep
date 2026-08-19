//
//  WorkoutViewModel.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//
import Foundation
import SwiftData
import Combine


@MainActor
final class WorkoutViewModel: ObservableObject {

    // MARK: - Flow

    @Published private(set) var state: WorkoutFlowState = .ready


    // MARK: - Routine

    let routine: Routine

    @Published private(set) var currentExerciseIndex = 0
    @Published private(set) var currentSetNumber = 1


    // MARK: - Current Set

    @Published var plannedReps: Int
    @Published var currentReps = 0

    @Published private(set) var elapsedSetTime: TimeInterval = 0


    // MARK: - Rest

    @Published private(set) var remainingRestTime: TimeInterval = 0


    // MARK: - Session

    private(set) var workoutSession: WorkoutSession?

    private var setStartedAt: Date?
    private var restStartedAt: Date?

    private var timer: Timer?


    // MARK: - Init

    init(routine: Routine) {
        self.routine = routine

        let firstExercise = routine.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .first

        self.plannedReps =
            firstExercise?.targetReps ?? 0
    }


    // MARK: - Computed

    private var sortedExercises: [RoutineExercise] {
        routine.exercises.sorted {
            $0.orderIndex < $1.orderIndex
        }
    }

    var currentExercise: RoutineExercise? {
        guard sortedExercises.indices.contains(
            currentExerciseIndex
        ) else {
            return nil
        }

        return sortedExercises[currentExerciseIndex]
    }


    // MARK: - Workout

    func startWorkout() {
        guard state == .ready else {
            return
        }

        workoutSession = WorkoutSession(
            mode: .routine,
            sourceRoutine: routine
        )

        currentExerciseIndex = 0
        currentSetNumber = 1
        currentReps = 0

        plannedReps =
            currentExercise?.targetReps ?? 0

        state = .exercising

        startSetTimer()
    }


    // MARK: - Repetitions

    func incrementReps() {
        guard state == .exercising else {
            return
        }

        currentReps += 1
    }

    func decrementReps() {
        guard state == .exercising,
              currentReps > 0
        else {
            return
        }

        currentReps -= 1
    }


    // MARK: - Set

    func completeSet() {
        guard state == .exercising,
              let session = workoutSession,
              let exercise = currentExercise
        else {
            return
        }

        stopTimer()

        let record = ExerciseSetRecord(
            exerciseType: exercise.exerciseType,
            setNumber: currentSetNumber,
            plannedReps: plannedReps,
            actualReps: currentReps,
            duration: elapsedSetTime
        )

        session.setRecords.append(record)

        state = .setCompleted
    }

    func continueAfterSet() {
        guard state == .setCompleted,
              let exercise = currentExercise
        else {
            return
        }

        if currentSetNumber < exercise.targetSets {
            startRest()
        } else {
            state = .exerciseCompleted
        }
    }


    // MARK: - Rest

    private func startRest() {
        guard let exercise = currentExercise else {
            return
        }

        stopTimer()

        state = .resting

        restStartedAt = .now
        remainingRestTime =
            exercise.targetRestDuration

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let restStartedAt = self.restStartedAt,
                      let exercise = self.currentExercise
                else {
                    return
                }

                let elapsed =
                    Date.now.timeIntervalSince(restStartedAt)

                let remaining =
                    exercise.targetRestDuration - elapsed

                self.remainingRestTime =
                    max(0, remaining)

                if remaining <= 0 {
                    self.startNextSet()
                }
            }
        }
    }

    func skipRest() {
        guard state == .resting else {
            return
        }

        startNextSet()
    }

    func startNextSet() {
        guard state == .resting else {
            return
        }

        stopTimer()

        currentSetNumber += 1
        currentReps = 0
        elapsedSetTime = 0

        plannedReps =
            currentExercise?.targetReps ?? 0

        state = .exercising

        startSetTimer()
    }


    // MARK: - Exercise

    func moveToNextExercise() {
        guard state == .exerciseCompleted else {
            return
        }

        let nextIndex =
            currentExerciseIndex + 1

        guard sortedExercises.indices.contains(nextIndex) else {
            state = .sessionReview
            return
        }

        currentExerciseIndex = nextIndex
        currentSetNumber = 1
        currentReps = 0
        elapsedSetTime = 0

        plannedReps =
            currentExercise?.targetReps ?? 0

        state = .exercising

        startSetTimer()
    }


    // MARK: - Session

    func completeWorkout() {
        guard state == .sessionReview,
              let session = workoutSession
        else {
            return
        }

        stopTimer()

        session.endedAt = .now
        session.completionStatus = .completed

        state = .completed
    }

    func interruptWorkout(
        reason: InterruptionReason
    ) {
        guard let session = workoutSession else {
            return
        }

        stopTimer()

        session.endedAt = .now
        session.completionStatus = .interrupted
        session.interruptionReason = reason

        state = .interrupted
    }


    // MARK: - Timer

    private func startSetTimer() {
        stopTimer()

        setStartedAt = .now
        elapsedSetTime = 0

        timer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let setStartedAt = self.setStartedAt
                else {
                    return
                }

                self.elapsedSetTime =
                    Date.now.timeIntervalSince(setStartedAt)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func cleanup() {
        stopTimer()
    }
}
