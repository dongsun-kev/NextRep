//
//  Models.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//

import Foundation
import SwiftData


// MARK: - Enums

enum ExerciseType: String, Codable, CaseIterable {
    case pushUp
    case pullUp
    case squat
}

enum SessionMode: String, Codable {
    case routine
    case amrap
}

enum SessionCompletionStatus: String, Codable {
    case inProgress
    case completed
    case interrupted
}

enum InterruptionReason: String, Codable {
    case pain
    case userQuit
    case other
}


// MARK: - Routine

@Model
final class Routine {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var exercises: [RoutineExercise]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        exercises: [RoutineExercise] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.exercises = exercises
    }
}


// MARK: - RoutineExercise

@Model
final class RoutineExercise {
    var id: UUID

    var exerciseType: ExerciseType
    var orderIndex: Int

    var targetSets: Int
    var targetReps: Int
    var targetRestDuration: TimeInterval

    var videoURLString: String?

    init(
        id: UUID = UUID(),
        exerciseType: ExerciseType,
        orderIndex: Int,
        targetSets: Int,
        targetReps: Int,
        targetRestDuration: TimeInterval = 60,
        videoURLString: String? = nil
    ) {
        self.id = id
        self.exerciseType = exerciseType
        self.orderIndex = orderIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRestDuration = targetRestDuration
        self.videoURLString = videoURLString
    }
}


// MARK: - WorkoutSession

@Model
final class WorkoutSession {
    var id: UUID

    var startedAt: Date
    var endedAt: Date?

    var mode: SessionMode
    var completionStatus: SessionCompletionStatus
    var interruptionReason: InterruptionReason?

    /// AMRAP review에서 사용자가 입력한
    /// 마지막 미완성 라운드의 누적 반복 수
    /// 일반 루틴 세션에서는 nil
    var additionalReps: Int?

    /// 운동 시작 시점의 루틴/챌린지 이름
    var routineNameSnapshot: String?

    var sourceRoutine: Routine?

    @Relationship(deleteRule: .cascade)
    var setRecords: [ExerciseSetRecord]

    @Relationship(deleteRule: .cascade)
    var amrapRoundRecords: [AMRAPRoundRecord]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        mode: SessionMode,
        completionStatus: SessionCompletionStatus = .inProgress,
        interruptionReason: InterruptionReason? = nil,
        additionalReps: Int? = nil,
        routineNameSnapshot: String? = nil,
        sourceRoutine: Routine? = nil,
        setRecords: [ExerciseSetRecord] = [],
        amrapRoundRecords: [AMRAPRoundRecord] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.completionStatus = completionStatus
        self.interruptionReason = interruptionReason
        self.additionalReps = additionalReps
        self.routineNameSnapshot = routineNameSnapshot
        self.sourceRoutine = sourceRoutine
        self.setRecords = setRecords
        self.amrapRoundRecords = amrapRoundRecords
    }
}


// MARK: - ExerciseSetRecord

@Model
final class ExerciseSetRecord {
    var id: UUID

    /// 동일한 운동 종류가 루틴에 여러 번 있을 때를 위한 원본 항목 ID
    var routineExerciseID: UUID?

    var exerciseType: ExerciseType
    var setNumber: Int

    /// 오늘 이 세트를 시작할 때의 목표 횟수
    var plannedReps: Int

    /// 사용자가 실제 수행한 횟수
    var actualReps: Int

    /// 실제 세트 수행 시간
    var duration: TimeInterval

    var completedAt: Date

    init(
        id: UUID = UUID(),
        routineExerciseID: UUID? = nil,
        exerciseType: ExerciseType,
        setNumber: Int,
        plannedReps: Int,
        actualReps: Int,
        duration: TimeInterval,
        completedAt: Date = .now
    ) {
        self.id = id
        self.routineExerciseID = routineExerciseID
        self.exerciseType = exerciseType
        self.setNumber = setNumber
        self.plannedReps = plannedReps
        self.actualReps = actualReps
        self.duration = duration
        self.completedAt = completedAt
    }
}


// MARK: - AMRAPRoundRecord

@Model
final class AMRAPRoundRecord {
    var id: UUID

    var roundNumber: Int
    var duration: TimeInterval
    var completedAt: Date

    init(
        id: UUID = UUID(),
        roundNumber: Int,
        duration: TimeInterval,
        completedAt: Date = .now
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.duration = duration
        self.completedAt = completedAt
    }
}
