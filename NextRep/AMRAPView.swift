//
//  AMRAPView.swift
//  NextRep
//


import SwiftUI
import SwiftData

struct AMRAPView: View {
    @StateObject private var viewModel: AMRAPViewModel
    @State private var partialRepsText = ""
    @State private var interruptPartialRepsText = ""
    @State private var isShowingInterruptConfirmation = false

    init(
        challengeDuration: TimeInterval = 20 * 60,
        modelContext: ModelContext
    ) {
        _viewModel = StateObject(
            wrappedValue: AMRAPViewModel(
                challengeDuration: challengeDuration,
                modelContext: modelContext
            )
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            if let message = viewModel.persistenceErrorMessage {
                Text("저장 실패: \(message)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.state == .running,
               let message = viewModel.resultInputErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            content
        }
        .padding()
        .toolbar {
            if viewModel.state == .completed ||
                viewModel.state == .interrupted {
                Button("새 Challenge") {
                    partialRepsText = ""
                    interruptPartialRepsText = ""
                    viewModel.prepareNewChallenge()
                }
            }
        }
        .alert("운동을 중단할까요?", isPresented: $isShowingInterruptConfirmation) {
            TextField("마지막 미완성 라운드 개수", text: $interruptPartialRepsText)
                .keyboardType(.numberPad)

            Button("중단", role: .destructive) {
                viewModel.interruptChallenge(
                    reason: .userQuit,
                    partialReps: Int(interruptPartialRepsText) ?? 0
                )
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("마지막 미완성 라운드에서 진행한 개수를 입력해주세요.")
        }
    }
}

private extension AMRAPView {
    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .ready:
            readyView
        case .running:
            runningView
        case .review:
            reviewView
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
                    Text("5·10·15 Challenge")
                        .font(.largeTitle.bold())

                    Text("세 운동을 모두 완료하면 1라운드예요.")
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.challengeDuration.formattedTime)
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(.tint)

                VStack(spacing: 16) {
                    ForEach(viewModel.exerciseTargets) { target in
                        HStack(spacing: 16) {
                            Image(systemName: target.exerciseType.symbolName)
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 44, height: 44)

                            Text(target.exerciseType.title)
                                .font(.headline)

                            Spacer()

                            Text("\(target.targetReps)회")
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                Button("Challenge 시작") {
                    viewModel.startChallenge()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(16)
        }
    }

    var runningView: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            Text(viewModel.remainingChallengeTime.formattedTime)
                .font(.largeTitle.bold().monospacedDigit())
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("완료 라운드")
                    .foregroundStyle(.secondary)
                Text("\(viewModel.completedRounds)")
                    .font(.largeTitle.bold())
            }

            VStack(spacing: 16) {
                ForEach(viewModel.exerciseTargets) { target in
                    HStack(spacing: 16) {
                        Image(systemName: viewModel.completedRounds > 0 ? "checkmark.circle.fill" : target.exerciseType.symbolName)
                            .font(.title2)
                            .foregroundStyle(viewModel.completedRounds > 0 ? Color.accentColor : Color.secondary)
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(target.exerciseType.title)
                                .font(.headline)

                            Text("라운드당 \(target.targetReps)회")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(viewModel.completedRounds)세트 완료")
                            .font(.subheadline.bold())
                            .foregroundStyle(.tint)
                    }
                    .padding(16)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }

            Button("\(viewModel.completedRounds + 1)라운드 완료") {
                viewModel.recordRound()
            }
            .buttonStyle(.borderedProminent)

            Button("운동 중단", role: .destructive) {
                isShowingInterruptConfirmation = true
            }
            .frame(minHeight: 44)
          }
          .padding(16)
        }
    }

    var reviewView: some View {
        VStack(spacing: 16) {
            Text("AMRAP 결과")
                .font(.largeTitle.bold())

            Text("완료 라운드: \(viewModel.completedRounds)")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("\(viewModel.completedRounds + 1)라운드에서 몇 개까지 진행했나요?")
                    .font(.headline)

                TextField("예: 11", text: $partialRepsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            if let message = viewModel.resultInputErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.exerciseTargets) { target in
                    let partialReps = viewModel.partialReps(
                        for: target,
                        totalPartialReps: parsedPartialReps
                    )
                    let totalReps = viewModel.completedRounds * target.targetReps + partialReps

                    LabeledContent(
                        target.exerciseType.title,
                        value: "\(viewModel.completedRounds)세트 · 총 \(totalReps)회"
                    )
                }
            }
            .font(.subheadline)

            if let session = viewModel.session {
                List(
                    session.amrapRoundRecords.sorted { $0.roundNumber < $1.roundNumber },
                    id: \AMRAPRoundRecord.id
                ) { record in
                    HStack {
                        Text("Round \(record.roundNumber)")
                        Spacer()
                        Text(record.duration.formattedTime)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 240)
            }

            Button("결과 저장") {
                viewModel.completeReview(
                    partialReps: Int(partialRepsText) ?? 0
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    var parsedPartialReps: Int {
        Int(partialRepsText) ?? 0
    }

    var completedView: some View {
        ContentUnavailableView(
            "AMRAP 완료",
            systemImage: "checkmark.circle.fill",
            description: Text("운동 결과가 저장되었습니다.")
        )
    }

    var interruptedView: some View {
        ContentUnavailableView(
            "AMRAP 중단",
            systemImage: "stop.circle",
            description: Text("완료 라운드와 마지막 진행 개수를 저장했습니다.")
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
