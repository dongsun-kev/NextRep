//
//  AMRAPViewModel.swift
//  NextRep
//


import Foundation
import SwiftData
import Combine

struct AMRAPExerciseTarget: Identifiable, Equatable {
    var id: ExerciseType { exerciseType }

    let exerciseType: ExerciseType
    let targetReps: Int

    static let standard: [AMRAPExerciseTarget] = [
        AMRAPExerciseTarget(exerciseType: .pullUp, targetReps: 5),
        AMRAPExerciseTarget(exerciseType: .pushUp, targetReps: 10),
        AMRAPExerciseTarget(exerciseType: .squat, targetReps: 15)
    ]
}

@MainActor
final class AMRAPViewModel: ObservableObject {
    @Published private(set) var state: AMRAPFlowState = .ready
    @Published private(set) var remainingChallengeTime: TimeInterval
    @Published private(set) var completedRounds = 0
    @Published private(set) var persistenceErrorMessage: String?
    @Published private(set) var resultInputErrorMessage: String?

    let challengeDuration: TimeInterval
    let exerciseTargets = AMRAPExerciseTarget.standard

    private(set) var session: WorkoutSession?

    private let modelContext: ModelContext
    private var currentRoundStartTime: Date?
    private var challengeEndTime: Date?
    private var timer: Timer?

    var repetitionsPerRound: Int {
        exerciseTargets.reduce(0) { $0 + $1.targetReps }
    }

    init(
        challengeDuration: TimeInterval = 20 * 60,
        modelContext: ModelContext
    ) {
        self.challengeDuration = challengeDuration
        self.remainingChallengeTime = challengeDuration
        self.modelContext = modelContext
    }

    deinit {
        timer?.invalidate()
    }

    func startChallenge() {
        guard state == .ready,
              challengeDuration > 0
        else {
            return
        }

        let newSession = WorkoutSession(
            mode: .amrap,
            additionalReps: 0,
            routineNameSnapshot: "5·10·15 Challenge"
        )

        modelContext.insert(newSession)

        guard saveContext() else {
            return
        }

        let startedAt = newSession.startedAt

        session = newSession
        completedRounds = 0
        resultInputErrorMessage = nil
        remainingChallengeTime = challengeDuration
        currentRoundStartTime = startedAt
        challengeEndTime = startedAt.addingTimeInterval(challengeDuration)
        state = .running

        startTimer()
    }

    func recordRound() {
        guard state == .running,
              let session,
              let currentRoundStartTime,
              let challengeEndTime
        else {
            return
        }

        let now = Date.now

        guard now < challengeEndTime else {
            finishChallenge()
            return
        }

        let record = AMRAPRoundRecord(
            roundNumber: completedRounds + 1,
            duration: now.timeIntervalSince(currentRoundStartTime),
            completedAt: now
        )

        session.amrapRoundRecords.append(record)
        session.additionalReps = 0

        guard saveContext() else {
            return
        }

        completedRounds += 1
        resultInputErrorMessage = nil
        self.currentRoundStartTime = now
    }

    func finishChallenge() {
        guard state == .running,
              let session
        else {
            return
        }

        session.endedAt = challengeEndTime ?? .now

        guard saveContext() else {
            return
        }

        stopTimer()
        remainingChallengeTime = 0
        state = .review
    }

    func completeReview(partialReps: Int) {
        guard state == .review,
              let session
        else {
            return
        }

        guard isValidPartialReps(partialReps) else {
            return
        }

        session.completionStatus = .completed
        session.interruptionReason = nil
        session.additionalReps = partialReps

        guard saveContext() else {
            return
        }

        state = .completed
    }

    func interruptChallenge(
        reason: InterruptionReason,
        partialReps: Int
    ) {
        guard state == .running,
              let session
        else {
            return
        }

        guard isValidPartialReps(partialReps) else {
            return
        }

        session.endedAt = .now
        session.completionStatus = .interrupted
        session.interruptionReason = reason
        session.additionalReps = partialReps

        guard saveContext() else {
            return
        }

        stopTimer()
        state = .interrupted
    }

    func prepareNewChallenge() {
        guard state == .completed || state == .interrupted else {
            return
        }

        stopTimer()
        session = nil
        completedRounds = 0
        remainingChallengeTime = challengeDuration
        currentRoundStartTime = nil
        challengeEndTime = nil
        persistenceErrorMessage = nil
        resultInputErrorMessage = nil
        state = .ready
    }

    func cleanup() {
        stopTimer()
    }

    func partialReps(
        for target: AMRAPExerciseTarget,
        totalPartialReps: Int
    ) -> Int {
        var remaining = max(0, totalPartialReps)

        for item in exerciseTargets {
            let itemReps = min(remaining, item.targetReps)

            if item.id == target.id {
                return itemReps
            }

            remaining -= itemReps
        }

        return 0
    }

    private func isValidPartialReps(_ partialReps: Int) -> Bool {
        guard (0..<repetitionsPerRound).contains(partialReps) else {
            resultInputErrorMessage = "0~\(repetitionsPerRound - 1)개만 입력할 수 있어요. \(repetitionsPerRound)개를 모두 했다면 라운드 완료로 기록해주세요."
            return false
        }

        resultInputErrorMessage = nil
        return true
    }

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.25,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRemainingTime()
            }
        }
    }

    private func updateRemainingTime() {
        guard state == .running,
              let challengeEndTime
        else {
            return
        }

        let remaining = challengeEndTime.timeIntervalSinceNow
        remainingChallengeTime = max(0, remaining)

        if remaining <= 0 {
            finishChallenge()
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
            print("SwiftData AMRAP 저장 실패:", error)
            return false
        }
    }
}
