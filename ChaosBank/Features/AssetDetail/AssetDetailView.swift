//
//  AssetDetailView.swift
//  ChaosBank
//

import SwiftUI

struct AssetDetailView: View {
    let symbol: String

    @Environment(AppServices.self) private var services
    @State private var timeframe = "1D"
    @State private var request: OrderRequest?

    private var asset: Asset? { SeedData.assets.first { $0.symbol == symbol } }
    private var quote: Quote? { services.market.quote(for: symbol) }
    private var price: Decimal { quote?.price ?? asset?.basePrice ?? 0 }
    private var changePct: Decimal { quote?.changePct ?? 0 }

    var body: some View {
        ChaosBankScreen(title: symbol, a11y: A11y.Asset.root, showBadge: false) {
            if let asset {
                content(asset)
            }
        }
        .onAppear { services.startFeed() }
        .navigationDestination(item: $request) { req in
            OrderView(request: req)
        }
    }

    @ViewBuilder
    private func content(_ asset: Asset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(asset.name).font(.appBody(14)).foregroundStyle(Palette.muted)
                .accessibilityIdentifier(A11y.Asset.symbol)
            LiveTickerText(text: "$" + MoneyFormat.price(price),
                           direction: quote?.lastDirection ?? .flat,
                           size: 40, weight: .bold, a11y: A11y.Asset.price)
            Text("\(MoneyFormat.percent(changePct)) today")
                .moneyStyle(15, weight: .semibold)
                .foregroundStyle(Palette.pnl(changePct))
                .accessibilityIdentifier(A11y.Asset.change)
        }

        SegmentBar(
            items: ["1D", "1W", "1M", "1Y"].map {
                SegmentItem(id: $0, title: $0, a11y: A11y.Asset.timeframe($0))
            },
            selection: $timeframe
        )

        Sparkline(symbol: symbol, up: changePct >= 0)
            .frame(height: 140)
            .padding(.vertical, 8)

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(label: "Market cap", value: marketCap(asset), a11y: A11y.Asset.statMarketCap)
            StatTile(label: "Volume", value: volume(asset), a11y: A11y.Asset.statVolume)
            StatTile(label: "Day high", value: "$" + MoneyFormat.price(quote?.dayHigh ?? price), a11y: A11y.Asset.statHigh)
            StatTile(label: "Day low", value: "$" + MoneyFormat.price(quote?.dayLow ?? price), a11y: A11y.Asset.statLow)
        }

        HStack(spacing: 12) {
            SecondaryButton(title: "Sell", systemImage: "arrow.up.right") {
                request = OrderRequest(symbol: symbol, side: .sell, capturedPrice: price)
            }
            .accessibilityIdentifier(A11y.Asset.sellButton)

            PrimaryButton(title: "Buy", systemImage: "arrow.down.left") {
                request = OrderRequest(symbol: symbol, side: .buy, capturedPrice: price)
            }
            .accessibilityIdentifier(A11y.Asset.buyButton)
            // `wrongA11yLabel`: the Buy button announces itself as "Sell".
            .accessibilityLabel(Defects.isActive(.wrongA11yLabel) ? Text("Sell") : Text("Buy"))
        }
    }

    private func marketCap(_ asset: Asset) -> String {
        // Deterministic pseudo market cap derived from the symbol.
        let shares = Decimal(1_000_000_000 + Int(StableHash.of(asset.symbol) % 4_000_000_000))
        let cap = (price * shares) / Decimal(1_000_000_000)
        return "$" + MoneyFormat.decimal(cap.rounded(scale: 1), fractionDigits: 1) + "B"
    }

    private func volume(_ asset: Asset) -> String {
        let vol = Decimal(10_000_000 + Int(StableHash.of(asset.symbol + "v") % 90_000_000))
        return "$" + MoneyFormat.decimal((vol / Decimal(1_000_000)).rounded(scale: 1), fractionDigits: 1) + "M"
    }
}
