//
//  MarketsView.swift
//  ChaosBank
//

import SwiftUI

struct MarketsView: View {
    @Environment(AppServices.self) private var services
    @State private var segment = "watchlist"

    private var assets: [Asset] {
        switch segment {
        case "stocks":
            // `cryptoShownInStocks`: crypto leaks into the Stocks segment.
            return SeedData.assets.filter { $0.kind == .stock || (Defects.isActive(.cryptoShownInStocks) && $0.kind == .crypto) }
        case "crypto":
            return SeedData.assets.filter { $0.kind == .crypto }
        default:
            // `watchlistShowsAll`: the watchlist shows every asset.
            if Defects.isActive(.watchlistShowsAll) { return SeedData.assets }
            return SeedData.assets.filter { SeedData.watchlistSymbols.contains($0.symbol) }
        }
    }

    /// Row identifier. The `duplicateAssetA11yId` defect collides NVDA onto
    /// AAPL's identifier, so two different rows share one identifier.
    private func rowA11y(_ symbol: String) -> String {
        if Defects.isActive(.duplicateAssetA11yId), symbol == "NVDA" {
            return A11y.Markets.asset("AAPL")
        }
        return A11y.Markets.asset(symbol)
    }

    var body: some View {
        ChaosBankScreen(title: "Markets", a11y: A11y.Markets.root) {
            if services.market.source == .live {
                HStack(spacing: 6) {
                    Circle()
                        .fill(services.market.liveConnected ? Palette.gain : Palette.muted)
                        .frame(width: 8, height: 8)
                    Text(services.market.liveConnected ? "LIVE · Yahoo Finance" : "Connecting…")
                        .font(.appMono(11, weight: .semibold))
                        .foregroundStyle(services.market.liveConnected ? Palette.gain : Palette.muted)
                }
                .accessibilityIdentifier(A11y.Markets.liveBadge)
            }

            SegmentBar(
                items: [
                    SegmentItem(id: "watchlist", title: "Watchlist", a11y: A11y.Markets.segmentWatchlist),
                    SegmentItem(id: "stocks", title: "Stocks", a11y: A11y.Markets.segmentStocks),
                    SegmentItem(id: "crypto", title: "Crypto", a11y: A11y.Markets.segmentCrypto),
                ],
                selection: $segment
            )

            CardSurface(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                        // `assetRowOpensWrongDetail`: open the next row's asset.
                        let targetSymbol = Defects.isActive(.assetRowOpensWrongDetail)
                            ? assets[(index + 1) % assets.count].symbol
                            : asset.symbol
                        NavigationLink {
                            AssetDetailView(symbol: targetSymbol)
                        } label: {
                            MarketRow(asset: asset, quote: services.market.quote(for: asset.symbol))
                        }
                        .accessibilityIdentifier(rowA11y(asset.symbol))
                        // `marketRowNoLabel`: strip the row's accessibility label.
                        .accessibilityLabel(Defects.isActive(.marketRowNoLabel) ? Text(" ") : Text(asset.symbol))
                        if index < assets.count - 1 {
                            Divider().overlay(Palette.line)
                        }
                    }
                }
            }
            .accessibilityIdentifier(A11y.Markets.list)
        }
        .onAppear { services.startFeed() }
    }
}

struct MarketRow: View {
    let asset: Asset
    let quote: Quote?

    private var price: Decimal { quote?.price ?? asset.basePrice }
    private var changePct: Decimal { quote?.changePct ?? 0 }
    /// `changePctSignFlipped`: the displayed % change is negated.
    private var shownChange: Decimal { Defects.isActive(.changePctSignFlipped) ? -changePct : changePct }
    private var direction: TickDirection { quote?.lastDirection ?? .flat }
    /// `priceMissingDecimals`: render whole-dollar prices.
    private var priceText: String {
        "$" + MoneyFormat.price(price, fractionDigits: Defects.isActive(.priceMissingDecimals) ? 0 : 2)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol)
                    .font(.appBody(16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(asset.name)
                    .font(.appBody(12))
                    .foregroundStyle(Palette.muted)
            }
            .frame(width: 110, alignment: .leading)

            // `sparklineHeavyPoints`: compute an absurd number of points.
            Sparkline(symbol: asset.symbol, up: changePct >= 0,
                      pointCount: Defects.isActive(.sparklineHeavyPoints) ? 4000 : 24)
                .frame(height: 32)

            VStack(alignment: .trailing, spacing: 2) {
                LiveTickerText(text: priceText, direction: direction,
                               size: 15, a11y: A11y.Markets.assetPrice(asset.symbol))
                Text(MoneyFormat.percent(shownChange))
                    .moneyStyle(12, weight: .semibold)
                    .foregroundStyle(Palette.pnl(shownChange))
                    .accessibilityIdentifier(A11y.Markets.assetChange(asset.symbol))
            }
            .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
