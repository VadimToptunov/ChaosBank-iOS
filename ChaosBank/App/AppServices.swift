//
//  AppServices.swift
//  ChaosBank
//
//  The shared service container injected through the environment. Holds the
//  backend, the live market store, and the active build config. `dataVersion`
//  ticks on every backend mutation so screens can refresh. `configVersion` ticks
//  when the active bug profile changes (via the developer menu) so the UI tree
//  rebuilds and re-reads the defect state.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppServices {
    private(set) var config: BuildConfig
    let backend: MockBackend
    let market: MarketStore

    /// Increments after every successful mutation.
    private(set) var dataVersion = 0
    /// Increments when the active profile / defect set changes at runtime.
    private(set) var configVersion = 0
    /// Simulated network environment (reliability cluster), chosen from the dev menu.
    private(set) var networkCondition: NetworkCondition = .normal
    /// True while cached data is served and writes fail.
    var offline: Bool { networkCondition == .offline }

    init(config: BuildConfig) {
        self.config = config
        self.backend = MockBackend(scenario: BackendScenario.from(config.activeDefects))
        self.market = MarketStore(seed: config.seed, assets: SeedData.assets, source: config.priceSource)
    }

    func setPriceSource(_ kind: PriceSourceKind) {
        config.priceSource = kind
        market.setSource(kind)
    }

    func setNetworkCondition(_ value: NetworkCondition) {
        networkCondition = value
        Task { await backend.setCondition(value) }
    }

    func setOffline(_ value: Bool) {
        setNetworkCondition(value ? .offline : .normal)
    }

    private func syncScenario() {
        let scenario = BackendScenario.from(config.activeDefects)
        Task { await backend.setScenario(scenario) }
    }

    func bumpData() { dataVersion += 1 }

    func startFeed() { market.start() }

    // MARK: - Runtime defect control (developer menu)

    func isActive(_ id: DefectID) -> Bool { config.activeDefects.contains(id) }

    func applyProfile(_ profile: BugProfile) {
        config.activeDefects = profile.defects
        config.label = profile.id
        Defects.configure(config)
        syncScenario()
        configVersion += 1
    }

    func applyDefects(_ ids: Set<DefectID>, label: String) {
        config.activeDefects = ids
        config.label = label
        Defects.configure(config)
        syncScenario()
        configVersion += 1
    }

    func toggle(_ id: DefectID) {
        if config.activeDefects.contains(id) {
            config.activeDefects.remove(id)
        } else {
            config.activeDefects.insert(id)
        }
        config.label = "custom"
        Defects.configure(config)
        syncScenario()
        configVersion += 1
    }
}
