//
//  WorkoutSessionView.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//
import SwiftUI
import Observation

// MARK: - TimeInterval Formatting Extension

extension TimeInterval {
    var formattedTime: String {
        let totalSeconds = max(0, Int(self))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension ExerciseType {
    var title: String {
        switch self {
        case .pushUp: return "푸시업"
        case .pullUp: return "풀업"
        case .squat: return "스쿼트"
        }
    }
}

// MARK: - Main WorkoutView

struct WorkoutView: View {
    @StateObject private var viewModel: WorkoutViewModel

    init(routine: Routine) {
        _viewModel = StateObject(
            wrappedValue: WorkoutViewModel(routine: routine)
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("현재 상태: \(stateText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            content

            Spacer()

            interruptButton
        }
        .padding()
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - State UI Routing

private extension WorkoutView {
    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .ready:
            readyView
        case .exercising:
            exercisingView
        case .setCompleted:
            setCompletedView
        case .resting:
            restingView
        case .exerciseCompleted:
            exerciseCompletedView
        case .sessionReview:
            sessionReviewView
        case .completed:
            completedView
        case .interrupted:
            interruptedView
        }
    }
}

// MARK: - Subviews

private extension WorkoutView {
    var readyView: some View {
        VStack(spacing: 20) {
            Text(viewModel.routine.name)
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 12) {
                ForEach(
                    viewModel.routine.exercises.sorted { $0.orderIndex < $1.orderIndex },
                    id: \RoutineExercise.id
                ) { exercise in
                    HStack {
                        Text(exercise.exerciseType.title)
                        Spacer()
                        Text("\(exercise.targetSets)세트 × \(exercise.targetReps)회")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("운동 시작") {
                viewModel.startWorkout()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var exercisingView: some View {
        VStack(spacing: 24) {
            if let exercise = viewModel.currentExercise {
                Text(exercise.exerciseType.title)
                    .font(.largeTitle.bold())

                Text("Set \(viewModel.currentSetNumber) / \(exercise.targetSets)")
                    .font(.headline)

                Text("목표 \(viewModel.plannedReps)회")
                    .foregroundStyle(.secondary)

                Text(viewModel.elapsedSetTime.formattedTime)
                    .font(.title2.monospacedDigit())

                Text("\(viewModel.currentReps)")
                    .font(.system(size: 72, weight: .bold))
                    .monospacedDigit()

                HStack(spacing: 24) {
                    Button {
                        viewModel.decrementReps()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.incrementReps()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("세트 완료") {
                    viewModel.completeSet()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    var setCompletedView: some View {
        VStack(spacing: 20) {
            Text("세트 완료")
                .font(.largeTitle.bold())

            Text("\(viewModel.currentReps)회")
                .font(.system(size: 56, weight: .bold))

            Text("수행 시간 \(viewModel.elapsedSetTime.formattedTime)")
                .foregroundStyle(.secondary)

            Button("계속") {
                viewModel.continueAfterSet()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var restingView: some View {
        VStack(spacing: 24) {
            Text("휴식")
                .font(.largeTitle.bold())

            Text(viewModel.remainingRestTime.formattedTime)
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()

            Text("다음 세트를 준비하세요")
                .foregroundStyle(.secondary)

            Button("휴식 건너뛰기") {
                viewModel.skipRest()
            }
            .buttonStyle(.bordered)
        }
    }

    var exerciseCompletedView: some View {
        VStack(spacing: 20) {
            if let exercise = viewModel.currentExercise {
                Text("\(exercise.exerciseType.title) 완료")
                    .font(.largeTitle.bold())
            }

            Button("다음 운동") {
                viewModel.moveToNextExercise()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var sessionReviewView: some View {
        VStack(spacing: 20) {
            Text("운동 결과")
                .font(.largeTitle.bold())

            if let session = viewModel.workoutSession {
                List(session.setRecords, id: \ExerciseSetRecord.id) { record in
                    VStack(alignment: .leading) {
                        Text(record.exerciseType.title)
                            .font(.headline)
                        Text("Set \(record.setNumber)")
                        Text("목표 \(record.plannedReps) / 실제 \(record.actualReps)")
                        Text(record.duration.formattedTime)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 300)
            }

            Button("운동 완료") {
                viewModel.completeWorkout()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("운동 완료")
                .font(.largeTitle.bold())

            Text("오늘 운동이 기록되었습니다.")
                .foregroundStyle(.secondary)
        }
    }

    var interruptedView: some View {
        VStack(spacing: 16) {
            Text("운동 중단")
                .font(.largeTitle.bold())
                .foregroundColor(.red)

            Text("완료된 세트 기록은 유지됩니다.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var interruptButton: some View {
        if viewModel.state != .ready &&
            viewModel.state != .completed &&
            viewModel.state != .interrupted {
            Button("운동 중단", role: .destructive) {
                viewModel.interruptWorkout(reason: .userQuit)
            }
        }
    }

    var stateText: String {
        switch viewModel.state {
        case .ready: return "ready"
        case .exercising: return "exercising"
        case .setCompleted: return "setCompleted"
        case .resting: return "resting"
        case .exerciseCompleted: return "exerciseCompleted"
        case .sessionReview: return "sessionReview"
        case .completed: return "completed"
        case .interrupted: return "interrupted"
        }
    }
}

// MARK: - Preview

#Preview {
    let routine = Routine(
        name: "상체 기본 루틴",
        exercises: [
            RoutineExercise(
                exerciseType: .pushUp,
                orderIndex: 0,
                targetSets: 2,
                targetReps: 10,
                targetRestDuration: 5 // 테스트용 5초 휴식
            ),
            RoutineExercise(
                exerciseType: .pullUp,
                orderIndex: 1,
                targetSets: 2,
                targetReps: 5,
                targetRestDuration: 5
            )
        ]
    )

    WorkoutView(routine: routine)
}
