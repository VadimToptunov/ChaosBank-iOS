//
//  SyncViewModel.swift
//  ChaosBank
//
//  A tiny concurrency playground: run N parallel "+1" operations against a shared
//  counter. The correct path uses an atomic increment. The `syncLostUpdate` defect
//  does a non-atomic read-modify-write, so concurrent increments clobber each other
//  and the final value is short — the classic lost-update race.
//

import Foundation
import Observation

@MainActor
@Observable
final class SyncViewModel {
    let concurrency = 20

    private(set) var counter = 0
    private(set) var running = false

    private let services: AppServices

    init(services: AppServices) { self.services = services }

    /// Expected final value after a run: start + concurrency.
    var expected: Int { counter + concurrency }

    func load() async {
        counter = await services.backend.syncValue()
    }

    func reset() async {
        await services.backend.syncReset()
        counter = 0
    }

    func runConcurrent() async {
        guard !running else { return }
        running = true
        defer { running = false }

        let backend = services.backend
        let lost = Defects.isActive(.syncLostUpdate)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    if lost {
                        // Non-atomic read-modify-write: interleaves and loses updates.
                        let v = await backend.syncValue()
                        await backend.syncSet(v + 1)
                    } else {
                        await backend.syncIncrement()
                    }
                }
            }
        }
        counter = await backend.syncValue()
    }
}
