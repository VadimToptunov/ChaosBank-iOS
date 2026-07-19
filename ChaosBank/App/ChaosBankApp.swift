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
    @State private var router = DeepLinkRouter()

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
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Palette.sand)
                .task { services.startFeed() }
                .onOpenURL { handleDeepLink($0) }
        }
    }

    /// A deep link selects a tab. Correct behaviour still requires the auth gate;
    /// the `deepLinkSkipsAuth` defect unlocks without any authentication.
    private func handleDeepLink(_ url: URL) {
        let uri = url.absoluteString
        router.tab = DeepLink.tabIndex(uri)
        if DeepLink.bypassesAuth(uri, defectActive: Defects.isActive(.deepLinkSkipsAuth)) {
            auth.forceUnlock()
        }
    }
}
