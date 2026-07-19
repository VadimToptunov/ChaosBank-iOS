//
//  SyncViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class SyncViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func make(_ defects: Set<DefectID> = []) -> SyncViewModel {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        return SyncViewModel(services: AppServices(config: config))
    }

    func testCleanNoUpdatesLost() async {
        let vm = make()
        await vm.reset()
        await vm.runConcurrent()
        XCTAssertEqual(vm.counter, vm.concurrency)
    }

    func testSyncLostUpdateRaceLosesUpdates() async {
        let vm = make([.syncLostUpdate])
        await vm.reset()
        await vm.runConcurrent()
        XCTAssertLessThan(vm.counter, vm.concurrency, "expected lost updates under the race")
        XCTAssertGreaterThanOrEqual(vm.counter, 1)
    }

    func testResetZeroesCounter() async {
        let vm = make()
        await vm.runConcurrent()
        await vm.reset()
        XCTAssertEqual(vm.counter, 0)
    }
}
