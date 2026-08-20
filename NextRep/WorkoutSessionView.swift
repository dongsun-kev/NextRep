//
//  WorkoutSessionView.swift
//  NextRep
//
//  Created by DS on 8/19/26.
//

import SwiftUI
import SwiftData

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

    var symbolName: String {
        switch self {
        case .pushUp: return "figure.strengthtraining.traditional"
        case .pullUp: return "figure.climbing"
        case .squat: return "figure.strengthtraining.functional"
        }
    }
}

struct WorkoutView: View {
    @StateObject private var viewModel: WorkoutViewModel
    @State private var isShowingInterruptionOptions = false

    init(
        routine: Routine,
        modelContext: ModelContext
    ) {
        _viewModel = StateObject(
            wrappedValue: WorkoutViewModel(
                routine: routine,
                modelContext: modelContext
            )
        )
    }

    var body: some View {
        content
            .navigationTitle(viewModel.routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(
                viewModel.state == .exercising ||
                    viewModel.state == .sessionReview
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.state == .exercising ||
                        viewModel.state == .sessionReview {
                        Button("중단", role: .destructive) {
                            isShowingInterruptionOptions = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                "운동을 중단할까요?",
                isPresented: $isShowingInterruptionOptions,
                titleVisibility: .visible
            ) {
                Button("통증으로 중단", role: .destructive) {
                    viewModel.interruptWorkout(reason: .pain)
                }

                Button("그만하기", role: .destructive) {
                    viewModel.interruptWorkout(reason: .userQuit)
                }

                Button("취소", role: .cancel) {}
            }
    }
}

private extension WorkoutView {
    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .ready:
            readyView
        case .exercising:
            exercisingView
        case .sessionReview:
            sessionReviewView
        case .completed:
            completedView
        case .interrupted:
            interruptedView
        }
    }

    var readyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘의 루틴")
                        .font(.largeTitle.bold())

                    Text("운동은 원하는 순서로 진행할 수 있어요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    ForEach(viewModel.exercises, id: \RoutineExercise.id) { exercise in
                        HStack(spacing: 16) {
                            Image(systemName: exercise.exerciseType.symbolName)
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.exerciseType.title)
                                    .font(.headline)

                                Text("\(exercise.targetSets)세트 · 세트당 \(exercise.targetReps)회")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                Button {
                    viewModel.startWorkout()
                } label: {
                    Text("운동 시작")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.exercises.isEmpty || viewModel.totalTargetSets == 0)
            }
            .padding(16)
        }
    }

    var exercisingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader

                if let restNotice = viewModel.restNotice {
                    restNoticeCard(restNotice)
                }

                VStack(spacing: 16) {
                    ForEach(viewModel.exercises, id: \RoutineExercise.id) { exercise in
                        exerciseProgressRow(exercise)
                    }
                }
            }
            .padding(16)
        }
    }

    var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("세트 진행")
                    .font(.title.bold())

                Spacer()

                Text(viewModel.elapsedSessionTime.formattedTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.progress)
                .tint(.accentColor)

            Text("\(viewModel.completedSets) / \(viewModel.totalTargetSets)세트")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func restNoticeCard(_ notice: RoutineRestNotice) -> some View {
        GroupBox {
            HStack(spacing: 16) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(notice.exerciseTitle) 휴식")
                        .font(.headline)

                    Text("\(viewModel.remainingRestTime.formattedTime) 동안 휴식하세요.")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("건너뛰기") {
                    viewModel.dismissRestNotice()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    func exerciseProgressRow(_ exercise: RoutineExercise) -> some View {
        let completed = viewModel.completedSetCount(for: exercise)
        let isCompleted = completed >= exercise.targetSets

        return HStack(spacing: 16) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : exercise.exerciseType.symbolName)
                .font(.title2)
                .foregroundStyle(isCompleted ? Color.accentColor : Color.secondary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.exerciseType.title)
                    .font(.headline)

                Text("목표 \(exercise.targetReps)회 · \(completed)/\(exercise.targetSets)세트")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ProgressView(
                    value: Double(completed),
                    total: Double(max(1, exercise.targetSets))
                )
                .tint(.accentColor)
            }

            Spacer()

            if completed > 0 {
                Button {
                    viewModel.undoLastSet(for: exercise)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("마지막 세트 취소")
            }

            Button {
                viewModel.completeNextSet(for: exercise)
            } label: {
                Image(systemName: "checkmark")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCompleted)
            .accessibilityLabel("\(exercise.exerciseType.title) 다음 세트 완료")
        }
        .padding(16)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    var sessionReviewView: some View {
        List {
            Section {
                LabeledContent("날짜", value: Date.now.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("완료 세트", value: "\(viewModel.completedSets)세트")
                LabeledContent("운동 시간", value: viewModel.elapsedSessionTime.formattedTime)
            } header: {
                Text("오늘 운동 기록")
            }

            Section("운동별 결과") {
                ForEach(viewModel.exercises, id: \RoutineExercise.id) { exercise in
                    LabeledContent {
                        Text("\(viewModel.completedSetCount(for: exercise))세트 · 세트당 \(exercise.targetReps)회")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label(exercise.exerciseType.title, systemImage: exercise.exerciseType.symbolName)
                    }
                }
            }

            Section {
                Button {
                    viewModel.completeWorkout()
                } label: {
                    Text("오늘 운동 저장")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)

                Button("세트 기록 수정") {
                    viewModel.editCompletedSets()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    var completedView: some View {
        ContentUnavailableView(
            "운동 완료",
            systemImage: "checkmark.circle.fill",
            description: Text("오늘 운동 기록을 저장했습니다.")
        )
    }

    var interruptedView: some View {
        ContentUnavailableView(
            "운동 중단",
            systemImage: "stop.circle",
            description: Text("완료한 세트까지 저장했습니다.")
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
