//
//  LocaleSettings.swift
//  ChaosBank
//
//  Layout-direction settings (Localization cluster). `rtl` mirrors the whole app; the
//  `rtlBreaksLayout` defect forces a specific row to stay left-to-right so it does not
//  mirror — the classic "hard-coded left/right instead of start/end" bug.
//

import Foundation
import Observation

@MainActor
@Observable
final class LocaleSettings {
    private(set) var rtl = false
    private(set) var locale: LocaleId = .enUS

    func enableRtl(_ value: Bool) { rtl = value }
    func selectLocale(_ value: LocaleId) { locale = value }

    /// Whether a row should be (incorrectly) forced left-to-right: only when the app
    /// is RTL and the defect is active. Unit-tested.
    static func forcesLtrRow(rtl: Bool) -> Bool {
        rtl && Defects.isActive(.rtlBreaksLayout)
    }
}
