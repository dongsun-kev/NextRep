//
//  PersistenceCheckView.swift
//  NextRep
//


import SwiftUI
import SwiftData

struct TodayHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    private var todaySessions: [WorkoutSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(todaySessions, id: \WorkoutSession.id) { session in
                    sessionSection(session)
                }
                .onDelete(perform: deleteSessions)
            }
            .overlay {
                if todaySessions.isEmpty {
                    ContentUnavailableView(
                        "오늘 운동 기록이 없어요",
                        systemImage: "figure.run"
                    )
                }
            }
            .navigationTitle("오늘 기록")
        }
    }

    @ViewBuilder
    private func sessionSection(_ session: WorkoutSession) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.routineNameSnapshot ?? session.mode.title)
                        .font(.headline)

                    Spacer()

                    Text(session.completionStatus.title)
                        .font(.caption.bold())
                        .foregroundStyle(session.completionStatus.color)
                }

                if session.mode == .amrap {
                    amrapSummary(session)
                } else {
                    routineSummary(session)
                }

                if session.completionStatus == .interrupted,
                   let reason = session.interruptionReason {
                    LabeledContent("중단 사유", value: reason.title)
                        .font(.subheadline)
                }

                HStack {
                    Text(session.startedAt.formatted(date: .omitted, time: .shortened))

                    if let endedAt = session.endedAt {
                        Text("–")
                        Text(endedAt.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private func routineSummary(_ session: WorkoutSession) -> some View {
        let groupedRecords = Dictionary(grouping: session.setRecords) { record in
            record.routineExerciseID?.uuidString ?? "legacy-\(record.exerciseType.rawValue)"
        }
        let groups = groupedRecords
            .map { key, records in
                RoutineRecordGroup(
                    id: key,
                    exerciseType: records[0].exerciseType,
                    records: records
                )
            }
            .sorted {
                ($0.records.map(\.completedAt).min() ?? .distantPast) <
                    ($1.records.map(\.completedAt).min() ?? .distantPast)
            }

        return VStack(alignment: .leading, spacing: 8) {
            ForEach(groups) { group in
                let totalReps = group.records.reduce(0) { $0 + $1.actualReps }

                LabeledContent(
                    group.exerciseType.title,
                    value: "\(group.records.count)세트 · \(totalReps)회"
                )
            }
        }
        .font(.subheadline)
    }

    private func amrapSummary(_ session: WorkoutSession) -> some View {
        let completedRounds = session.amrapRoundRecords.count
        let partialReps = session.additionalReps ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            LabeledContent("완료 라운드", value: "\(completedRounds)라운드")
            LabeledContent("마지막 진행", value: "\(partialReps)개")

            ForEach(AMRAPExerciseTarget.standard) { target in
                let partialExerciseReps = self.partialReps(
                    for: target,
                    totalPartialReps: partialReps
                )
                let totalReps = completedRounds * target.targetReps + partialExerciseReps

                LabeledContent(
                    target.exerciseType.title,
                    value: "\(completedRounds)세트 · \(totalReps)회"
                )
            }

            if !session.amrapRoundRecords.isEmpty {
                DisclosureGroup("라운드별 기록") {
                    ForEach(
                        session.amrapRoundRecords.sorted { $0.roundNumber < $1.roundNumber },
                        id: \AMRAPRoundRecord.id
                    ) { record in
                        LabeledContent(
                            "Round \(record.roundNumber)",
                            value: record.duration.formattedTime
                        )
                    }
                }
            }
        }
        .font(.subheadline)
    }

    private func partialReps(
        for target: AMRAPExerciseTarget,
        totalPartialReps: Int
    ) -> Int {
        var remaining = max(0, totalPartialReps)

        for item in AMRAPExerciseTarget.standard {
            let itemReps = min(remaining, item.targetReps)

            if item.id == target.id {
                return itemReps
            }

            remaining -= itemReps
        }

        return 0
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todaySessions[index])
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            print("운동 기록 삭제 실패:", error)
        }
    }
}

private struct RoutineRecordGroup: Identifiable {
    let id: String
    let exerciseType: ExerciseType
    let records: [ExerciseSetRecord]
}

private extension SessionMode {
    var title: String {
        switch self {
        case .routine: return "일반 루틴"
        case .amrap: return "Challenge"
        }
    }
}

private extension SessionCompletionStatus {
    var title: String {
        switch self {
        case .inProgress: return "진행 중"
        case .completed: return "완료"
        case .interrupted: return "중단"
        }
    }

    var color: Color {
        switch self {
        case .inProgress: return .secondary
        case .completed: return .accentColor
        case .interrupted: return .red
        }
    }
}

private extension InterruptionReason {
    var title: String {
        switch self {
        case .pain: return "통증"
        case .userQuit: return "사용자 중단"
        case .other: return "기타"
        }
    }
}

#Preview {
    TodayHistoryView()
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
