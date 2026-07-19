//
//  SyncView.swift
//  ChaosBank
//
//  A concurrency playground surfacing the `syncLostUpdate` race.
//

import SwiftUI

struct SyncView: View {
    @Environment(AppServices.self) private var services
    @State private var vm: SyncViewModel?

    var body: some View {
        ChaosBankScreen(title: "Sync playground", a11y: A11y.Sync.root, showBadge: false) {
            if let vm {
                content(vm)
            }
        }
        .task {
            if vm == nil { vm = SyncViewModel(services: services) }
            await vm?.reset()
            await vm?.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: SyncViewModel) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text("Counter").font(.appBody(13)).foregroundStyle(Palette.muted)
                Text("\(vm.counter)")
                    .font(.appMono(44, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .accessibilityIdentifier(A11y.Sync.counter)
                Text("Run \(vm.concurrency) parallel +1 → expect \(vm.expected)")
                    .font(.appBody(12)).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier(A11y.Sync.expected)
            }
        }

        PrimaryButton(title: "Run \(vm.concurrency) concurrent +1", enabled: !vm.running) {
            Task { await vm.runConcurrent() }
        }
        .accessibilityIdentifier(A11y.Sync.runButton)

        SecondaryButton(title: "Reset", systemImage: "arrow.counterclockwise") {
            Task { await vm.reset() }
        }
        .accessibilityIdentifier(A11y.Sync.resetButton)
    }
}
