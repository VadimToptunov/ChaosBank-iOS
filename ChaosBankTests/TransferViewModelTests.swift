//
//  TransferViewModelTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class TransferViewModelTests: XCTestCase {

    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func make(_ defects: Set<DefectID> = []) async -> (TransferViewModel, AppServices) {
        let config = BuildConfig(seed: 0, activeDefects: defects, label: "t")
        Defects.configure(config)
        let s = AppServices(config: config)
        let m = TransferViewModel(services: s)
        await m.load()
        return (m, s)
    }

    func testValidationHappyPath() async {
        let (m, _) = await make()
        m.recipient = "Alex"; m.amountText = "120"
        XCTAssertTrue(m.canContinue)
        XCTAssertEqual(m.balanceAfter?.amount, m.fromBalance - 120)
    }

    func testBlocksEmptyRecipientAndZero() async {
        let (m, _) = await make()
        m.recipient = "   "; m.amountText = "50"
        XCTAssertFalse(m.canContinue, "whitespace recipient trimmed to empty")
        m.recipient = "Alex"; m.amountText = "0"
        XCTAssertFalse(m.canContinue, "zero blocked")
    }

    func testOverBalanceBlocked() async {
        let (m, _) = await make()
        m.recipient = "Alex"; m.amountText = "999999"
        XCTAssertFalse(m.canContinue)
    }

    func testAmountExceedsBalanceAllowedDefect() async {
        let (m, _) = await make([.amountExceedsBalanceAllowed])
        m.recipient = "Alex"; m.amountText = "999999"
        XCTAssertTrue(m.canContinue)
    }

    func testZeroAmountAcceptedDefect() async {
        let (m, _) = await make([.zeroAmountAccepted])
        m.recipient = "Alex"; m.amountText = "0"
        XCTAssertTrue(m.canContinue)
    }

    func testWhitespaceRecipientDefect() async {
        let (m, _) = await make([.whitespaceRecipient])
        m.recipient = "   "; m.amountText = "50"
        XCTAssertTrue(m.canContinue)
    }

    func testConfirmDebitsBalance() async {
        let (m, s) = await make()
        m.recipient = "Alex"; m.amountText = "120"
        let before = await s.backend.fetchAccount(.EUR)?.balance ?? 0
        await m.confirmTransfer()
        XCTAssertTrue(m.succeeded)
        let after = await s.backend.fetchAccount(.EUR)?.balance ?? 0
        XCTAssertEqual(before - after, 120)
    }

    func testTransferDebitsWrongAccountDefect() async {
        let (m, s) = await make([.transferDebitsWrongAccount])
        m.recipient = "Alex"; m.amountText = "100"
        let usdBefore = await s.backend.fetchAccount(.USD)?.balance ?? 0
        await m.confirmTransfer()
        let usdAfter = await s.backend.fetchAccount(.USD)?.balance ?? 0
        XCTAssertEqual(usdBefore - usdAfter, 100, "debited USD instead of EUR")
    }

    func testTimeoutAsSuccessDefect() async {
        let (m, _) = await make([.timeoutAsSuccess])
        m.recipient = "Alex"; m.amountText = "50"
        await m.confirmTransfer()
        XCTAssertTrue(m.succeeded, "timeout reported as success")
    }

    func testTimeoutSurfacesErrorWhenClean() async {
        // A transfer that times out on the wire without the timeoutAsSuccess defect
        // surfaces an error + retry, not success.
        let config = BuildConfig(seed: 0, activeDefects: [], label: "t")
        Defects.configure(config)
        let s = AppServices(config: config)
        await s.backend.setScenario(BackendScenario(timeoutAsSuccess: true))
        let m = TransferViewModel(services: s)
        await m.load()
        m.recipient = "Alex"; m.amountText = "50"
        await m.confirmTransfer()
        XCTAssertFalse(m.succeeded)
        XCTAssertTrue(m.canRetry)
    }
}
