//
//  ChaosBankApp.swift
//  ChaosBank
//
//  Entry point. Resolves the build seed from launch args / environment, wires the
//  defect registry, and boots the shared services.
//

import SwiftUI

@main
struct ChaosBankApp: App {
    @State private var services: AppServices
    @State private var auth = AuthFlow(startUnlocked: LaunchOptions.current.startUnlocked)

    init() {
        let config = BuildConfig.resolve()
        Defects.configure(config)
        _services = State(initialValue: AppServices(config: config))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .environment(auth)
                .preferredColorScheme(.dark)
                .tint(Palette.sand)
                .task { services.startFeed() }
        }
    }
}
