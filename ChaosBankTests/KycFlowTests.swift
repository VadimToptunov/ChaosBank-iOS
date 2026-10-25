//
//  KycFlowTests.swift
//  ChaosBankTests
//

import XCTest
@testable import ChaosBank

@MainActor
final class KycFlowTests: XCTestCase {
    override func tearDown() {
        Defects.configure(BuildConfig(seed: 0, activeDefects: [], label: "clean"))
        super.tearDown()
    }

    private func use(_ defects: Set<DefectID>) {
        Defects.configure(BuildConfig(seed: 0, activeDefects: defects, label: defects.isEmpty ? "clean" : "t"))
    }

    private let valid = KycDocumentScan(name: KycReview.accountHolder, number: "P4916204",
                                        expiry: KycReview.date(2031, 4, 30))
    private let expired = KycDocumentScan(name: KycReview.accountHolder, number: "P4916204",
                                          expiry: KycReview.date(2024, 1, 31))
    private let otherName = KycDocumentScan(name: "ALEX MORGAN", number: "P4916204",
                                            expiry: KycReview.date(2031, 4, 30))
    private let today = KycReview.date(2026, 10, 25)

    // MARK: Review rules

    func testValidDocumentAndMatchingSelfieVerify() {
        use([])
        XCTAssertEqual(KycReview.decide(document: valid, selfie: .match, today: today), .verified)
    }

    func testExpiredDocumentRejectedUnlessDefect() {
        use([])
        XCTAssertEqual(KycReview.decide(document: expired, selfie: .match, today: today), .rejected("Document expired"))
        use([.kycAcceptsExpiredDocument])
        XCTAssertEqual(KycReview.decide(document: expired, selfie: .match, today: today), .verified)
    }

    func testOtherNameRejectedUnlessDefect() {
        use([])
        XCTAssertEqual(KycReview.decide(document: otherName, selfie: .match, today: today),
                       .rejected("Name doesn't match the account holder"))
        use([.kycNameMismatchAccepted])
        XCTAssertEqual(KycReview.decide(document: otherName, selfie: .match, today: today), .verified)
    }

    func testMismatchedSelfieRejectedUnlessDefect() {
        use([])
        XCTAssertEqual(KycReview.decide(document: valid, selfie: .mismatch, today: today),
                       .rejected("Face doesn't match the document"))
        use([.kycSelfieMismatchAccepted])
        XCTAssertEqual(KycReview.decide(document: valid, selfie: .mismatch, today: today), .verified)
    }

    func testStuckPendingReportsApprovedCheckAsPending() {
        use([.kycStuckPending])
        XCTAssertEqual(KycReview.decide(document: valid, selfie: .match, today: today), .pending)
    }

    // MARK: Flow

    func testHappyPathVerifiesTheStore() async {
        use([])
        let store = KycStore(verified: false)
        let flow = KycFlowModel(scanner: ScriptedDocumentScanner(script: "valid"),
                                faceCheck: ScriptedSelfieChecker(script: "match"))
        await flow.scanDocument()
        XCTAssertEqual(flow.document?.name, KycReview.accountHolder)
        await flow.takeSelfie()
        XCTAssertTrue(flow.canSubmit)
        await flow.submit(to: store)
        XCTAssertEqual(flow.outcome, .verified)
        XCTAssertTrue(store.verified)
    }

    func testUnreadableDocumentBlocksTheSelfie() async {
        use([])
        let flow = KycFlowModel(scanner: ScriptedDocumentScanner(script: "unreadable"),
                                faceCheck: ScriptedSelfieChecker(script: "match"))
        await flow.scanDocument()
        XCTAssertEqual(flow.document?.isReadable, false)
        XCTAssertFalse(flow.canTakeSelfie)
        XCTAssertFalse(flow.canSubmit)
    }

    func testNoFaceBlocksSubmit() async {
        use([])
        let flow = KycFlowModel(scanner: ScriptedDocumentScanner(script: "valid"),
                                faceCheck: ScriptedSelfieChecker(script: "noFace"))
        await flow.scanDocument()
        await flow.takeSelfie()
        XCTAssertEqual(flow.selfie, .noFace)
        XCTAssertFalse(flow.canSubmit)
    }

    func testRejectedOrPendingLeavesTheStoreUnverified() async {
        use([.kycStuckPending])
        let store = KycStore(verified: false)
        let flow = KycFlowModel(scanner: ScriptedDocumentScanner(script: "valid"),
                                faceCheck: ScriptedSelfieChecker(script: "match"))
        await flow.scanDocument()
        await flow.takeSelfie()
        await flow.submit(to: store)
        XCTAssertEqual(flow.outcome, .pending)
        XCTAssertFalse(store.verified)
    }

    func testUnknownScriptsFallBackToTheHappyPath() async {
        let doc = await ScriptedDocumentScanner(script: "nonsense").scan(.idCard)
        XCTAssertTrue(doc.isReadable)
        let selfie = await ScriptedSelfieChecker(script: "nonsense").check(against: doc)
        XCTAssertEqual(selfie, .match)
    }

    func testLaunchOptionsReadTheKycScripts() {
        let opts = LaunchOptions.resolve(defaults: UserDefaults(suiteName: "kyc-test")!,
                                         environment: ["CHAOSBANK_KYC_UNVERIFIED": "1",
                                                       "CHAOSBANK_KYC_DOCUMENT": "expired",
                                                       "CHAOSBANK_KYC_SELFIE": "mismatch"])
        XCTAssertTrue(opts.kycUnverified)
        XCTAssertEqual(opts.kycDocument, "expired")
        XCTAssertEqual(opts.kycSelfie, "mismatch")
    }
}
