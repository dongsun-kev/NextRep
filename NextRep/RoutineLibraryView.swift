//
//  RoutineLibraryView.swift
//  NextRep
//

import SwiftData
import SwiftUI

struct RoutineLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse)
    private var routines: [Routine]

    @State private var editorPresentation: RoutineEditorPresentation?
    @State private var routinePendingDeletion: Routine?
    @State private var isShowingDeleteConfirmation = false
    @State private var persistenceErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("루틴이 없습니다", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("자주 하는 운동과 세트 구성을 루틴으로 만들어 보세요.")
                    } actions: {
                        Button("첫 루틴 만들기") {
                            presentEditor(for: nil)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(routines, id: \Routine.id) { routine in
                            routineLink(routine)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("삭제", role: .destructive) {
                                        requestDeletion(of: routine)
                                    }

                                    Button("수정") {
                                        presentEditor(for: routine)
                                    }
                                    .tint(.accentColor)
                                }
                                .contextMenu {
                                    Button {
                                        presentEditor(for: routine)
                                    } label: {
                                        Label("루틴 수정", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        requestDeletion(of: routine)
                                    } label: {
                                        Label("루틴 삭제", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("일반 루틴")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentEditor(for: nil)
                    } label: {
                        Label("루틴 추가", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(item: $editorPresentation) { presentation in
            NavigationStack {
                RoutineEditorView(routine: presentation.routine)
            }
        }
        .alert(
            "루틴을 삭제할까요?",
            isPresented: $isShowingDeleteConfirmation,
            presenting: routinePendingDeletion
        ) { routine in
            Button("삭제", role: .destructive) {
                deleteRoutine(routine)
            }
            Button("취소", role: .cancel) {}
        } message: { routine in
            Text("‘\(routine.name)’과 루틴에 포함된 운동 구성이 삭제됩니다.")
        }
        .alert(
            "변경 사항을 저장하지 못했습니다",
            isPresented: Binding(
                get: { persistenceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        persistenceErrorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }

    private func routineLink(_ routine: Routine) -> some View {
        NavigationLink {
            WorkoutView(
                routine: routine,
                modelContext: modelContext
            )
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.name)
                        .font(.headline)

                    Text(routineSummary(routine))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func routineSummary(_ routine: Routine) -> String {
        let exerciseCount = routine.exercises.count
        let setCount = routine.exercises.reduce(0) { result, exercise in
            result + exercise.targetSets
        }
        return "운동 \(exerciseCount)개 · 총 \(setCount)세트"
    }

    private func presentEditor(for routine: Routine?) {
        editorPresentation = RoutineEditorPresentation(routine: routine)
    }

    private func requestDeletion(of routine: Routine) {
        routinePendingDeletion = routine
        isShowingDeleteConfirmation = true
    }

    private func deleteRoutine(_ routine: Routine) {
        modelContext.delete(routine)

        do {
            try modelContext.save()
            routinePendingDeletion = nil
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = error.localizedDescription
        }
    }
}

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let routine: Routine?

    @State private var name: String
    @State private var exerciseDrafts: [RoutineExerciseDraft]
    @State private var persistenceErrorMessage: String?

    init(routine: Routine? = nil) {
        self.routine = routine

        let sortedExercises = routine?.exercises.sorted {
            $0.orderIndex < $1.orderIndex
        } ?? []

        _name = State(initialValue: routine?.name ?? "")
        _exerciseDrafts = State(
            initialValue: sortedExercises.map { exercise in
                RoutineExerciseDraft(exercise)
            }
        )
    }

    var body: some View {
        Form {
            Section("루틴 정보") {
                TextField("루틴 이름", text: $name)
                    .textInputAutocapitalization(.never)
            }

            Section {
                ForEach($exerciseDrafts) { $draft in
                    VStack(alignment: .leading, spacing: 16) {
                        Label(
                            draft.exerciseType.title,
                            systemImage: draft.exerciseType.symbolName
                        )
                        .font(.headline)
                        .foregroundStyle(.tint)

                        Picker("운동 종류", selection: $draft.exerciseType) {
                            ForEach(ExerciseType.allCases, id: \.self) { exerciseType in
                                Text(exerciseType.title)
                                    .tag(exerciseType)
                            }
                        }

                        Stepper(value: $draft.targetSets, in: 1...20) {
                            LabeledContent("목표 세트", value: "\(draft.targetSets)세트")
                        }

                        Stepper(value: $draft.targetReps, in: 1...100) {
                            LabeledContent("세트당 횟수", value: "\(draft.targetReps)회")
                        }

                        Stepper(
                            value: $draft.targetRestSeconds,
                            in: 0...600,
                            step: 5
                        ) {
                            LabeledContent(
                                "세트 후 휴식",
                                value: formattedRestDuration(draft.targetRestSeconds)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onDelete(perform: deleteExerciseDrafts)
                .onMove(perform: moveExerciseDrafts)

                Button {
                    addExerciseDraft()
                } label: {
                    Label("운동 추가", systemImage: "plus.circle")
                        .frame(minHeight: 44)
                }
            } header: {
                Text("운동 구성")
            } footer: {
                Text("편집을 누르면 운동 순서를 바꾸거나 삭제할 수 있습니다.")
            }
        }
        .navigationTitle(routine == nil ? "새 루틴" : "루틴 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    dismiss()
                }
            }

            ToolbarItemGroup(placement: .confirmationAction) {
                if !exerciseDrafts.isEmpty {
                    EditButton()
                }

                Button("저장") {
                    saveRoutine()
                }
                .disabled(trimmedName.isEmpty)
            }
        }
        .alert(
            "루틴을 저장하지 못했습니다",
            isPresented: Binding(
                get: { persistenceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        persistenceErrorMessage = nil
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addExerciseDraft() {
        exerciseDrafts.append(
            RoutineExerciseDraft(
                exerciseType: .pushUp,
                targetSets: 3,
                targetReps: 10,
                targetRestSeconds: 60
            )
        )
    }

    private func deleteExerciseDrafts(at offsets: IndexSet) {
        exerciseDrafts.remove(atOffsets: offsets)
    }

    private func moveExerciseDrafts(from offsets: IndexSet, to destination: Int) {
        exerciseDrafts.move(fromOffsets: offsets, toOffset: destination)
    }

    private func formattedRestDuration(_ seconds: Int) -> String {
        guard seconds >= 60 else {
            return "\(seconds)초"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if remainingSeconds == 0 {
            return "\(minutes)분"
        }

        return "\(minutes)분 \(remainingSeconds)초"
    }

    private func saveRoutine() {
        guard !trimmedName.isEmpty else {
            return
        }

        let savedRoutine: Routine
        if let routine {
            savedRoutine = routine
        } else {
            savedRoutine = Routine(name: trimmedName)
            modelContext.insert(savedRoutine)
        }

        savedRoutine.name = trimmedName

        let existingExercises = savedRoutine.exercises
        let existingExercisesByID = Dictionary(
            uniqueKeysWithValues: existingExercises.map { ($0.id, $0) }
        )

        var updatedExercises: [RoutineExercise] = []

        for (orderIndex, draft) in exerciseDrafts.enumerated() {
            let exercise: RoutineExercise

            if let existingExercise = existingExercisesByID[draft.id] {
                exercise = existingExercise
                exercise.exerciseType = draft.exerciseType
                exercise.targetSets = draft.targetSets
                exercise.targetReps = draft.targetReps
                exercise.targetRestDuration = TimeInterval(draft.targetRestSeconds)
            } else {
                exercise = RoutineExercise(
                    id: draft.id,
                    exerciseType: draft.exerciseType,
                    orderIndex: orderIndex,
                    targetSets: draft.targetSets,
                    targetReps: draft.targetReps,
                    targetRestDuration: TimeInterval(draft.targetRestSeconds)
                )
                modelContext.insert(exercise)
            }

            exercise.orderIndex = orderIndex
            updatedExercises.append(exercise)
        }

        let updatedExerciseIDs = Set(updatedExercises.map(\.id))
        let removedExercises = existingExercises.filter {
            !updatedExerciseIDs.contains($0.id)
        }

        savedRoutine.exercises = updatedExercises
        removedExercises.forEach(modelContext.delete)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            persistenceErrorMessage = error.localizedDescription
        }
    }
}

private struct RoutineEditorPresentation: Identifiable {
    let id = UUID()
    let routine: Routine?
}

private struct RoutineExerciseDraft: Identifiable {
    let id: UUID
    var exerciseType: ExerciseType
    var targetSets: Int
    var targetReps: Int
    var targetRestSeconds: Int

    init(
        id: UUID = UUID(),
        exerciseType: ExerciseType,
        targetSets: Int,
        targetReps: Int,
        targetRestSeconds: Int
    ) {
        self.id = id
        self.exerciseType = exerciseType
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRestSeconds = targetRestSeconds
    }

    init(_ exercise: RoutineExercise) {
        id = exercise.id
        exerciseType = exercise.exerciseType
        targetSets = exercise.targetSets
        targetReps = exercise.targetReps
        targetRestSeconds = max(0, Int(exercise.targetRestDuration.rounded()))
    }
}

#Preview {
    RoutineLibraryView()
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
