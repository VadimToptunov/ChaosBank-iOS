//
//  TransferViewModel.swift
//  ChaosBank
//

import Foundation
import Observation

@MainActor
@Observable
final class TransferViewModel {
    var recipient = ""
    var amountText = ""
    var note = ""
    var showConfirm = false
    var isSubmitting = false
    var succeeded = false
    var errorMessage: String?
    /// True after a timeout, when a Retry is offered. The retry reuses the same
    /// idempotency key — correct backends dedupe it; `retryDuplicate` double-posts.
    var canRetry = false
    private var idempotencyKey = UUID().uuidString

    let fromCurrency: Currency = .EUR
    private(set) var fromBalance: Decimal = 0

    private let services: AppServices

    init(services: AppServices) { self.services = services }

    func load() async {
        fromBalance = (await services.backend.fetchAccount(fromCurrency))?.balance ?? 0
    }

    /// The parsed amount, which may be zero or negative.
    var parsedAmount: Decimal? { AmountParser.parse(amountText) }

    var amount: Decimal? {
        guard let a = parsedAmount, a > 0 else { return nil }
        return a
    }

    var balanceAfter: Money? {
        (amount ?? parsedAmount).map { Money(fromBalance - $0, fromCurrency) }
    }

    /// Recipient passes validation.
    ///
    /// Correct path trims whitespace first, so a spaces-only recipient is empty.
    /// The `whitespaceRecipient` defect skips trimming.
    private var recipientValid: Bool {
        if Defects.isActive(.whitespaceRecipient) {
            return !recipient.isEmpty
        }
        return !recipient.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The recipient value actually used for the transfer.
    var effectiveRecipient: String {
        Defects.isActive(.whitespaceRecipient) ? recipient : recipient.trimmingCharacters(in: .whitespaces)
    }

    var canContinue: Bool {
        guard recipientValid, let a = parsedAmount else { return false }
        // Correct: the amount must not exceed the balance. The
        // `amountExceedsBalanceAllowed` defect skips this client-side check.
        if a > fromBalance && !Defects.isActive(.amountExceedsBalanceAllowed) {
            return false
        }
        // Correct: amount must be strictly positive. The `zeroAmountAccepted`
        // defect allows a zero (or, combined with parsing, non-positive) amount.
        if Defects.isActive(.zeroAmountAccepted) {
            return a >= 0
        }
        return a > 0
    }

    /// Confirm the transfer.
    ///
    /// Correct behavior is idempotent: a re-entrant call while one is in flight
    /// is ignored, so a rapid double-tap on Confirm still sends exactly once.
    /// The `doubleCharge` defect removes that guard, so two taps send twice.
    func confirmTransfer() async {
        guard let amount = parsedAmount else { return }

        if !Defects.isActive(.doubleCharge) {
            guard !isSubmitting else { return }
        }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil

        do {
            try await services.backend.transfer(from: fromCurrency, amount: amount,
                                                recipient: effectiveRecipient, note: note,
                                                idempotencyKey: idempotencyKey)
            services.bumpData()
            succeeded = true
            canRetry = false
        } catch BackendError.timeout {
            // The server may have committed; the client didn't get the ack.
            services.bumpData()
            if Defects.isActive(.timeoutAsSuccess) {
                // Buggy: report success despite never receiving confirmation.
                succeeded = true
            } else {
                errorMessage = "Request timed out — you can retry safely."
                canRetry = true
            }
        } catch BackendError.insufficientFunds {
            errorMessage = "Insufficient funds"
        } catch {
            errorMessage = "Transfer failed"
        }
    }

    /// Retry a timed-out transfer, reusing the same idempotency key.
    func retry() async {
        await confirmTransfer()
    }
}
