//
//  KycView.swift
//  ChaosBank
//
//  The identity-verification flow, pushed from the Card tab. One screen whose
//  sections unlock in order: document → selfie → submit → result.
//

import SwiftUI

struct KycView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var flow = KycFlowModel()

    var body: some View {
        ChaosBankScreen(title: "Verify identity", a11y: A11y.Kyc.root, showBadge: false) {
            if let outcome = flow.outcome {
                result(outcome)
            } else {
                documentStep
                if flow.document?.isReadable == true { selfieStep }
                PrimaryButton(title: "Submit for review", systemImage: "checkmark.shield",
                              enabled: flow.canSubmit) {
                    Task { await flow.submit(to: services.kyc) }
                }
                .accessibilityIdentifier(A11y.Kyc.submitButton)
                if flow.isWorking { ProgressView().tint(Palette.sand) }
            }
        }
    }

    private var documentStep: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Your document").font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                SegmentBar(
                    items: KycDocumentKind.allCases.map {
                        SegmentItem(id: $0.rawValue, title: $0.title,
                                    a11y: $0 == .passport ? A11y.Kyc.docPassport : A11y.Kyc.docIdCard)
                    },
                    selection: Binding(get: { flow.kind.rawValue },
                                       set: { flow.kind = KycDocumentKind(rawValue: $0) ?? .passport })
                )
                SecondaryButton(title: flow.document == nil ? "Scan document" : "Scan again",
                                systemImage: "doc.viewfinder") {
                    Task { await flow.scanDocument() }
                }
                .accessibilityIdentifier(A11y.Kyc.scanButton)

                if let doc = flow.document {
                    if doc.isReadable {
                        field("Name", doc.name ?? "", A11y.Kyc.docName)
                        field("Number", doc.number ?? "", A11y.Kyc.docNumber)
                        field("Expires", doc.expiry.map(Self.dateText) ?? "", A11y.Kyc.docExpiry)
                    } else {
                        Text("Couldn't read the document — try again in better light")
                            .font(.appBody(13, weight: .medium)).foregroundStyle(Palette.loss)
                            .accessibilityIdentifier(A11y.Kyc.scanError)
                    }
                }
            }
        }
    }

    private var selfieStep: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("2. A quick selfie").font(.appBody(15, weight: .semibold)).foregroundStyle(Palette.text)
                SecondaryButton(title: flow.selfie == nil ? "Take selfie" : "Retake selfie",
                                systemImage: "person.crop.circle") {
                    Task { await flow.takeSelfie() }
                }
                .accessibilityIdentifier(A11y.Kyc.selfieButton)
                if let selfie = flow.selfie {
                    Text(selfie.message)
                        .font(.appBody(13, weight: .medium))
                        .foregroundStyle(selfie == .match ? Palette.gain : Palette.loss)
                        .accessibilityIdentifier(A11y.Kyc.selfieResult)
                }
            }
        }
    }

    private func result(_ outcome: KycOutcome) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 10) {
                switch outcome {
                case .verified:
                    resultTitle("Identity verified", color: Palette.gain)
                case .pending:
                    resultTitle("Under review", color: Palette.sand)
                    reason("We'll let you know when the check is complete.")
                case .rejected(let why):
                    resultTitle("Verification failed", color: Palette.loss)
                    reason(why)
                }
                PrimaryButton(title: "Done") { dismiss() }
                    .accessibilityIdentifier(A11y.Kyc.doneButton)
            }
        }
    }

    private func resultTitle(_ text: String, color: Color) -> some View {
        Text(text).font(.appDisplay(20, weight: .bold)).foregroundStyle(color)
            .accessibilityIdentifier(A11y.Kyc.resultTitle)
    }

    private func reason(_ text: String) -> some View {
        Text(text).font(.appBody(14)).foregroundStyle(Palette.muted)
            .accessibilityIdentifier(A11y.Kyc.resultReason)
    }

    private func field(_ label: String, _ value: String, _ a11y: String) -> some View {
        HStack {
            Text(label).font(.appBody(13)).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).font(.appMono(13, weight: .medium)).foregroundStyle(Palette.text)
                .accessibilityIdentifier(a11y)
        }
    }

    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}
