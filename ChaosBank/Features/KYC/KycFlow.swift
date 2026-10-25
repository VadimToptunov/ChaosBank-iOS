//
//  KycFlow.swift
//  ChaosBank
//
//  Mock identity verification (KYC): choose a document → "scan" it → take a
//  "selfie" → submit → verified / rejected / pending. The simulator has no camera,
//  so the scanner and the face check sit behind small protocols whose default
//  implementations replay what the launch options ask for
//  (`-ChaosBankKycDocument`, `-ChaosBankKycSelfie`). A real app would put its
//  scanning SDK behind the same seam.
//
//  The review rules are written correctly; four defects override them at single,
//  guarded points: `kycAcceptsExpiredDocument`, `kycNameMismatchAccepted`,
//  `kycSelfieMismatchAccepted`, `kycStuckPending`.
//

import Foundation
import Observation

// MARK: - Scan results

nonisolated enum KycDocumentKind: String, CaseIterable, Sendable {
    case passport, idCard

    var title: String { self == .passport ? "Passport" : "ID card" }
}

/// What the document scanner read. `nil` fields mean the scan was unreadable.
nonisolated struct KycDocumentScan: Equatable, Sendable {
    let name: String?
    let number: String?
    let expiry: Date?

    var isReadable: Bool { name != nil && number != nil && expiry != nil }
}

nonisolated enum KycSelfieScan: String, Sendable {
    case match, mismatch, noFace

    var message: String {
        switch self {
        case .match: return "Face matches the document"
        case .mismatch: return "Face doesn't match the document"
        case .noFace: return "No face detected — try again"
        }
    }
}

// MARK: - Hardware seams

protocol KycDocumentScanning { func scan(_ kind: KycDocumentKind) async -> KycDocumentScan }
protocol KycSelfieChecking { func check(against document: KycDocumentScan) async -> KycSelfieScan }

/// Replays `-ChaosBankKycDocument`: valid | expired | unreadable | nameMismatch.
struct ScriptedDocumentScanner: KycDocumentScanning {
    let script: String

    func scan(_ kind: KycDocumentKind) async -> KycDocumentScan {
        try? await Task.sleep(for: .milliseconds(600))
        let number = kind == .passport ? "P4916204" : "ID7731205"
        switch script {
        case "expired":
            return KycDocumentScan(name: KycReview.accountHolder, number: number, expiry: KycReview.date(2024, 1, 31))
        case "unreadable":
            return KycDocumentScan(name: nil, number: nil, expiry: nil)
        case "nameMismatch":
            return KycDocumentScan(name: "ALEX MORGAN", number: number, expiry: KycReview.date(2031, 4, 30))
        default:
            return KycDocumentScan(name: KycReview.accountHolder, number: number, expiry: KycReview.date(2031, 4, 30))
        }
    }
}

/// Replays `-ChaosBankKycSelfie`: match | mismatch | noFace.
struct ScriptedSelfieChecker: KycSelfieChecking {
    let script: String

    func check(against document: KycDocumentScan) async -> KycSelfieScan {
        try? await Task.sleep(for: .milliseconds(600))
        return KycSelfieScan(rawValue: script) ?? .match
    }
}

// MARK: - Review rules

nonisolated enum KycOutcome: Equatable, Sendable {
    case verified
    case rejected(String)
    case pending
}

enum KycReview {
    /// The account holder's name as it appears on their documents.
    static let accountHolder = "VADIM TOPTUNOV"

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar(identifier: .gregorian).date(from: c) ?? .distantPast
    }

    /// The decision on a readable document and a detected face.
    static func decide(document: KycDocumentScan, selfie: KycSelfieScan, today: Date = Date()) -> KycOutcome {
        // `kycAcceptsExpiredDocument`: the expiry date isn't checked.
        if let expiry = document.expiry, expiry < today, !Defects.isActive(.kycAcceptsExpiredDocument) {
            return .rejected("Document expired")
        }
        // `kycNameMismatchAccepted`: the document's name isn't compared with the account holder.
        if document.name != accountHolder, !Defects.isActive(.kycNameMismatchAccepted) {
            return .rejected("Name doesn't match the account holder")
        }
        // `kycSelfieMismatchAccepted`: a face that doesn't match still passes.
        if selfie == .mismatch, !Defects.isActive(.kycSelfieMismatchAccepted) {
            return .rejected("Face doesn't match the document")
        }
        // `kycStuckPending`: an approved check is reported as still under review.
        return Defects.isActive(.kycStuckPending) ? .pending : .verified
    }
}

// MARK: - Flow

@MainActor
@Observable
final class KycFlowModel {
    var kind: KycDocumentKind = .passport
    private(set) var document: KycDocumentScan?
    private(set) var selfie: KycSelfieScan?
    private(set) var outcome: KycOutcome?
    private(set) var isWorking = false

    private let scanner: KycDocumentScanning
    private let faceCheck: KycSelfieChecking

    init(scanner: KycDocumentScanning = ScriptedDocumentScanner(script: LaunchOptions.current.kycDocument),
         faceCheck: KycSelfieChecking = ScriptedSelfieChecker(script: LaunchOptions.current.kycSelfie)) {
        self.scanner = scanner
        self.faceCheck = faceCheck
    }

    var canTakeSelfie: Bool { document?.isReadable == true && !isWorking }
    /// Submit needs a readable document and a detected face.
    var canSubmit: Bool { canTakeSelfie && (selfie == .match || selfie == .mismatch) }

    func scanDocument() async {
        isWorking = true
        document = await scanner.scan(kind)
        selfie = nil
        isWorking = false
    }

    func takeSelfie() async {
        guard let document, document.isReadable else { return }
        isWorking = true
        selfie = await faceCheck.check(against: document)
        isWorking = false
    }

    func submit(to store: KycStore) async {
        guard canSubmit, let document, let selfie else { return }
        isWorking = true
        try? await Task.sleep(for: .milliseconds(800))
        let result = KycReview.decide(document: document, selfie: selfie)
        outcome = result
        if result == .verified { store.applyVerified(true) }
        isWorking = false
    }
}
