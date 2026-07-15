//
//  LivePriceService.swift
//  ChaosBank
//
//  Real market data from the public Yahoo Finance chart endpoint (no API key).
//  This is the deliberately non-deterministic "chaos" data source — enable it
//  from the developer menu or `-priceSource live`. The default stays the seeded
//  simulation so the reference defects remain reproducible.
//

import Foundation

nonisolated struct LiveTick: Sendable {
    let price: Double
    let previousClose: Double
    let dayHigh: Double
    let dayLow: Double
}

actor LivePriceService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (ChaosBank)"]
        self.session = URLSession(configuration: config)
    }

    /// Maps app tickers to Yahoo symbols (crypto needs the -USD suffix).
    private static func yahooSymbol(_ appSymbol: String) -> String {
        switch appSymbol {
        case "BTC": return "BTC-USD"
        case "ETH": return "ETH-USD"
        default: return appSymbol
        }
    }

    func fetch(_ appSymbols: [String]) async -> [String: LiveTick] {
        await withTaskGroup(of: (String, LiveTick)?.self) { group in
            for symbol in appSymbols {
                group.addTask { await self.fetchOne(symbol) }
            }
            var result: [String: LiveTick] = [:]
            for await pair in group {
                if let (symbol, tick) = pair { result[symbol] = tick }
            }
            return result
        }
    }

    private func fetchOne(_ appSymbol: String) async -> (String, LiveTick)? {
        let yahoo = Self.yahooSymbol(appSymbol)
        guard let url = URL(string:
            "https://query1.finance.yahoo.com/v8/finance/chart/\(yahoo)?interval=1m&range=1d")
        else { return nil }

        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(YahooChartResponse.self, from: data),
              let meta = decoded.chart.result?.first?.meta,
              let price = meta.regularMarketPrice
        else { return nil }

        let prevClose = meta.previousClose ?? meta.chartPreviousClose ?? price
        let tick = LiveTick(price: price,
                            previousClose: prevClose,
                            dayHigh: meta.regularMarketDayHigh ?? max(price, prevClose),
                            dayLow: meta.regularMarketDayLow ?? min(price, prevClose))
        return (appSymbol, tick)
    }
}

private nonisolated struct YahooChartResponse: Decodable {
    let chart: Chart
    nonisolated struct Chart: Decodable { let result: [ChartResult]? }
    nonisolated struct ChartResult: Decodable { let meta: Meta }
    nonisolated struct Meta: Decodable {
        let regularMarketPrice: Double?
        let previousClose: Double?
        let chartPreviousClose: Double?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
    }
}
