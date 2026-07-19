//
//  DeepLinkRouter.swift
//  ChaosBank
//
//  Shared, observable target tab for an incoming deep link. TabBarView follows it.
//

import Foundation
import Observation

@MainActor
@Observable
final class DeepLinkRouter {
    var tab: Int?
}
