//
//  Components.swift
//  ChaosBank
//
//  Small reusable building blocks styled from the design tokens.
//

import SwiftUI

// MARK: - Surface

struct CardSurface<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    /// Renders the disabled appearance without affecting interactivity. Used by
    /// the `disabledButtonTappable` defect: a button that looks disabled but fires.
    var looksDisabled: Bool = false
    let action: () -> Void

    private var dimmed: Bool { !enabled || looksDisabled }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.appBody(16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Palette.bg)
            .background(dimmed ? Palette.sand.opacity(0.35) : Palette.sand)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.appBody(16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(Palette.text)
            .background(Palette.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            )
        }
    }
}

// MARK: - Segmented control

struct SegmentItem: Identifiable, Equatable {
    let id: String
    let title: String
    let a11y: String
}

struct SegmentBar: View {
    let items: [SegmentItem]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = item.id == selection
                Button {
                    selection = item.id
                } label: {
                    Text(item.title)
                        .font(.appBody(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? Palette.bg : Palette.muted)
                        .background(isSelected ? Palette.sand : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityIdentifier(item.a11y)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingA11y: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.appDisplay(18, weight: .semibold))
                .foregroundStyle(Palette.text)
            Spacer()
            if let trailing {
                Button(action: { trailingAction?() }) {
                    Text(trailing)
                        .font(.appBody(14, weight: .semibold))
                        .foregroundStyle(Palette.sand)
                }
                .accessibilityIdentifier(trailingA11y ?? "")
            }
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let label: String
    let value: String
    var a11y: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.appBody(12))
                .foregroundStyle(Palette.muted)
            Text(value)
                .moneyStyle(15, weight: .semibold)
                .foregroundStyle(Palette.text)
                .accessibilityIdentifier(a11y ?? "")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Toast

struct Toast: View {
    let message: String
    var a11y: String? = nil

    var body: some View {
        Text(message)
            .font(.appBody(15, weight: .semibold))
            .foregroundStyle(Palette.bg)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Palette.gain)
            .clipShape(Capsule())
            .accessibilityIdentifier(a11y ?? "")
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}
