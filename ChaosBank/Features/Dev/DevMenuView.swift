//
//  DevMenuView.swift
//  ChaosBank
//
//  Hidden developer menu (long-press / triple-tap the build badge). Switch bug
//  profiles or toggle individual defects at runtime. Changes apply immediately
//  and rebuild the UI tree via AppServices.configVersion.
//

import SwiftUI

struct DevMenuView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    private var groupedDefects: [(category: DefectCategory, defects: [Defect])] {
        DefectCategory.allCases.compactMap { category in
            let defects = DefectRegistry.all.filter { $0.category == category }
            return defects.isEmpty ? nil : (category, defects)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    activeHeader

                    NavigationLink {
                        ExercisesView()
                    } label: {
                        HStack {
                            Label("Exercises", systemImage: "list.bullet.rectangle")
                                .font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                            Spacer()
                            Text("\(Exercises.all.count)").font(.appMono(13)).foregroundStyle(Palette.muted)
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        .padding(14)
                        .background(Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityIdentifier(A11y.Dev.exercises)

                    NavigationLink {
                        SyncView()
                    } label: {
                        HStack {
                            Label("Sync playground", systemImage: "arrow.triangle.2.circlepath")
                                .font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                            Spacer()
                            Text("race").font(.appMono(13)).foregroundStyle(Palette.muted)
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        .padding(14)
                        .background(Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityIdentifier(A11y.Dev.sync)

                    section("Price data") {
                        SegmentBar(
                            items: PriceSourceKind.allCases.map {
                                SegmentItem(id: $0.rawValue, title: $0.title,
                                            a11y: A11y.Dev.priceSourceOption($0.rawValue))
                            },
                            selection: Binding(
                                get: { services.market.source.rawValue },
                                set: { services.setPriceSource(PriceSourceKind(rawValue: $0) ?? .simulated) }
                            )
                        )
                        .accessibilityIdentifier(A11y.Dev.priceSource)
                        Text(services.market.source == .live
                             ? "Real Yahoo Finance quotes — non-deterministic."
                             : "Seeded simulation — reproducible for tests.")
                            .font(.appBody(11)).foregroundStyle(Palette.muted)
                    }

                    section("Network") {
                        SegmentBar(
                            items: NetworkCondition.allCases.map {
                                SegmentItem(id: $0.rawValue, title: $0.title,
                                            a11y: A11y.Dev.networkConditionOption($0.rawValue))
                            },
                            selection: Binding(
                                get: { services.networkCondition.rawValue },
                                set: { services.setNetworkCondition(NetworkCondition(rawValue: $0) ?? .normal) }
                            )
                        )
                        .accessibilityIdentifier(A11y.Dev.networkCondition)
                        Text(networkHint(services.networkCondition))
                            .font(.appBody(11)).foregroundStyle(Palette.muted)
                    }

                    section("Localization") {
                        CardSurface {
                            Toggle(isOn: Binding(get: { services.locale.rtl },
                                                 set: { services.locale.enableRtl($0) })) {
                                Text("RTL layout")
                                    .font(.appBody(15, weight: .medium)).foregroundStyle(Palette.text)
                            }
                            .tint(Palette.sand)
                            .accessibilityIdentifier(A11y.Dev.rtlToggle)
                        }
                        Text("Mirror the app right-to-left (Arabic/Hebrew).")
                            .font(.appBody(11)).foregroundStyle(Palette.muted)
                    }

                    section("Security") {
                        CardSurface {
                            HStack {
                                Text("Session token storage")
                                    .font(.appBody(13)).foregroundStyle(Palette.muted)
                                Spacer()
                                Text(TokenStore.shared.storageDescription)
                                    .font(.appMono(12, weight: .semibold))
                                    .foregroundStyle(TokenStore.shared.isTokenInUserDefaults ? Palette.loss : Palette.gain)
                                    .accessibilityIdentifier(A11y.Dev.tokenStorage)
                            }
                        }
                    }

                    section("Profiles") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(BugProfiles.all) { profile in
                                profileChip(profile)
                            }
                        }
                    }

                    section("Defects (\(services.config.activeDefects.count) active)") {
                        VStack(spacing: 16) {
                            ForEach(groupedDefects, id: \.category) { group in
                                categoryBlock(group.category, group.defects)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.bg)
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Palette.sand)
                        .accessibilityIdentifier(A11y.Dev.close)
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .accessibilityIdentifier(A11y.Dev.menu)
    }

    private var activeHeader: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text("Active profile").font(.appBody(12)).foregroundStyle(Palette.muted)
                Text(services.config.label)
                    .font(.appDisplay(20, weight: .bold))
                    .foregroundStyle(Palette.sand)
                    .accessibilityIdentifier(A11y.Dev.activeLabel)
                Text("Build \(services.config.version) · RNG seed \(services.config.seedBadge)")
                    .font(.appMono(11)).foregroundStyle(Palette.muted)
            }
        }
    }

    private func profileChip(_ profile: BugProfile) -> some View {
        let isActive = services.config.label == profile.id
        return Button {
            services.applyProfile(profile)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.title)
                    .font(.appBody(14, weight: .semibold))
                    .foregroundStyle(isActive ? Palette.bg : Palette.text)
                Text("\(profile.defects.count) defects")
                    .font(.appBody(11))
                    .foregroundStyle(isActive ? Palette.bg.opacity(0.7) : Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isActive ? Palette.sand : Palette.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityIdentifier(A11y.Dev.profile(profile.id))
    }

    private func categoryBlock(_ category: DefectCategory, _ defects: [Defect]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.title.uppercased())
                .font(.appBody(11, weight: .semibold))
                .foregroundStyle(Palette.muted)
            CardSurface(padding: 8) {
                VStack(spacing: 0) {
                    ForEach(Array(defects.enumerated()), id: \.element.id) { index, defect in
                        Toggle(isOn: Binding(
                            get: { services.isActive(defect.id) },
                            set: { _ in services.toggle(defect.id) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(defect.title)
                                    .font(.appBody(13, weight: .medium))
                                    .foregroundStyle(Palette.text)
                                Text(defect.id.rawValue)
                                    .font(.appMono(10)).foregroundStyle(Palette.muted)
                            }
                        }
                        .tint(Palette.sand)
                        .accessibilityIdentifier(A11y.Dev.defectToggle(defect.id))
                        .padding(.vertical, 6)
                        if index < defects.count - 1 { Divider().overlay(Palette.line) }
                    }
                }
            }
        }
    }

    private func networkHint(_ condition: NetworkCondition) -> String {
        switch condition {
        case .offline: return "Reads serve cached data; writes fail."
        case .slow: return "Every call gets a large extra latency."
        case .flaky: return "Writes fail transiently at random."
        case .normal: return "Online — live reads and writes."
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.appDisplay(17, weight: .semibold)).foregroundStyle(Palette.text)
            content()
        }
    }
}
