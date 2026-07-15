//
//  ExercisesView.swift
//  ChaosBank
//
//  In-app browser over the machine-readable exercise catalog. Tapping "Apply"
//  activates that exercise's defect(s) so the tester can reproduce it live.
//

import SwiftUI

struct ExercisesView: View {
    @Environment(AppServices.self) private var services

    private let order = ["junior", "middle", "senior"]

    private var grouped: [(difficulty: String, items: [Exercise])] {
        order.map { level in
            (level, Exercises.all.filter { $0.difficulty == level })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(Exercises.all.count) exercises · one per defect")
                    .font(.appBody(12)).foregroundStyle(Palette.muted)

                ForEach(grouped, id: \.difficulty) { group in
                    if !group.items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.difficulty.uppercased())
                                .font(.appBody(12, weight: .bold)).foregroundStyle(Palette.sand)
                            ForEach(group.items) { exercise in
                                card(exercise)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.bg)
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .accessibilityIdentifier(A11y.Dev.exercisesList)
    }

    private func card(_ exercise: Exercise) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(exercise.id).font(.appMono(11, weight: .bold)).foregroundStyle(Palette.sand)
                    Spacer()
                    Text(exercise.category).font(.appBody(11)).foregroundStyle(Palette.muted)
                }
                Text(exercise.title).font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                Text(exercise.task).font(.appBody(13)).foregroundStyle(Palette.muted)
                HStack(spacing: 12) {
                    Text("Clean: \(exercise.expectedClean)")
                        .font(.appBody(11)).foregroundStyle(Palette.gain)
                }
                Text("Buggy: \(exercise.expectedBuggy)")
                    .font(.appBody(11)).foregroundStyle(Palette.loss)
                Button {
                    let ids = Set(exercise.defects.compactMap { DefectID(rawValue: $0) })
                    services.applyDefects(ids, label: exercise.id)
                } label: {
                    Text("Apply this exercise")
                        .font(.appBody(13, weight: .semibold))
                        .foregroundStyle(Palette.bg)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Palette.sand)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier(A11y.Dev.exerciseApply(exercise.id))
            }
        }
        .accessibilityIdentifier(A11y.Dev.exercise(exercise.id))
    }
}
