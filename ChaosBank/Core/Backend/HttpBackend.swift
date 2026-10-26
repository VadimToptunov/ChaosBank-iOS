//
//  HttpBackend.swift
//  ChaosBank
//
//  ChaosBank-Server over HTTP (`-ChaosBankBackend <url>`). Each launch gets its own
//  chaos session on the server, so it starts from the seed data like the embedded
//  mock. It signs in on its own, with the demo OTP, and signs in again when a token
//  expires.
//
//  Defects: client-side ones stay in the app as always. The active defects the server
//  also knows (its `/chaos/catalog`) are switched on in the session. The network
//  condition goes to the session too, except `offline`, which stays client-side:
//  writes fail before any request, as in `MockBackend`.
//
//  The server prices exchanges itself, so a client defect that only changes the
//  credited amount passed to `exchange` has no effect here. An order goes up with the
//  app's own execution price (as a limit when it is a limit), so order defects carry
//  over.
//

import Foundation

actor HttpBackend: Backend {
    /// The server's demo OTP (ChaosBank-Server `AuthRules.OTP_CODE`, the apps' mock OTP).
    static let demoOTP = "424242"

    nonisolated let label: String
    private let base: URL
    private let seed: Int
    private let username: String
    private let session: URLSession

    private var sessionID: String?
    private var token: String?
    private var serverDefects: Set<String>?
    private var defects: Set<DefectID>
    private var condition: NetworkCondition = .normal
    /// The session's defects / network need pushing before the next call.
    private var configDirty = false
    /// One sign-in at a time; later callers await the same attempt.
    private var setup: Task<Void, Error>?

    // Last good reads, served when a read fails.
    private var accounts: [Account] = []
    private var transactions: [Transaction] = []
    private var holdings: [Holding] = []
    private var orders: [Order] = []
    private var counter = 0

    init(baseURL: URL, seed: Int, defects: Set<DefectID>, username: String = "chaosbank-app",
         timeout: TimeInterval = 15) {
        self.base = baseURL
        self.label = "Server \(baseURL.absoluteString)"
        self.seed = seed
        self.defects = defects
        self.username = username
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: configuration)
    }

    func setScenario(_ scenario: BackendScenario) {
        // Server-side scenarios follow the defects (setDefects).
    }

    func setCondition(_ value: NetworkCondition) { condition = value; configDirty = true }

    func setDefects(_ defects: Set<DefectID>) { self.defects = defects; configDirty = true }

    // MARK: - Reads

    func fetchAccounts() async -> [Account] {
        await read({ accounts }) {
            let list = try JSONDecoder().decode([AccountDTO].self, from: try await call("GET", "/v1/accounts")).map(\.model)
            accounts = list
            return list
        }
    }

    func fetchAccount(_ currency: Currency, extraDelay: Duration) async -> Account? {
        if extraDelay > .zero { try? await Task.sleep(for: extraDelay) }
        return await read({ accounts.first { $0.currency == currency } }) {
            do {
                return try JSONDecoder().decode(AccountDTO.self, from: try await call("GET", "/v1/accounts/\(currency.rawValue)")).model
            } catch BackendError.unknownAccount {
                return nil
            }
        }
    }

    func fetchTransactions() async -> [Transaction] {
        await read({ transactions }) {
            let list = try JSONDecoder().decode(PageDTO.self, from: try await call("GET", "/v1/transactions")).items.map(\.model)
            transactions = list
            return list
        }
    }

    func fetchHoldings() async -> [Holding] {
        await read({ holdings }) {
            let list = try JSONDecoder().decode([HoldingDTO].self, from: try await call("GET", "/v1/holdings")).map(\.model)
            holdings = list
            return list
        }
    }

    func fetchOrders() async -> [Order] {
        await read({ orders }) {
            let list = try JSONDecoder().decode([OrderDTO].self, from: try await call("GET", "/v1/orders")).map(\.model)
            orders = list
            return list
        }
    }

    func syncValue() async -> Int {
        await read({ counter }) { try await value(call("GET", "/v1/sync/counter")) }
    }

    func syncSet(_ value: Int) async { _ = try? await self.value(call("PUT", "/v1/sync/counter", body: ["value": value])) }

    func syncIncrement() async { _ = try? await value(call("POST", "/v1/sync/counter/increment")) }

    func syncReset() async { _ = try? await value(call("POST", "/v1/sync/counter/reset")) }

    // MARK: - Writes

    @discardableResult
    func transfer(from currency: Currency, amount: Decimal, recipient: String, note: String,
                  idempotencyKey: String) async throws -> Transaction {
        let body: [String: Any] = ["from": currency.rawValue, "amount": Self.plain(amount), "recipient": recipient, "note": note]
        return try JSONDecoder().decode(TransactionDTO.self, from: try await write("/v1/transfers", body, key: idempotencyKey)).model
    }

    @discardableResult
    func deposit(to currency: Currency, amount: Decimal, title: String) async throws -> Transaction {
        let body: [String: Any] = ["to": currency.rawValue, "amount": Self.plain(amount), "title": title]
        return try JSONDecoder().decode(TransactionDTO.self, from: try await write("/v1/deposits", body)).model
    }

    @discardableResult
    func exchange(sell: Currency, get: Currency, debit: Decimal, credited: Decimal) async throws -> Transaction {
        let body: [String: Any] = ["sell": sell.rawValue, "get": get.rawValue, "amount": Self.plain(debit)]
        return try JSONDecoder().decode(ExchangeDTO.self, from: try await write("/v1/exchanges", body)).transaction.model
    }

    func placeOrder(_ order: Order) async throws -> Order {
        var body: [String: Any] = [
            "symbol": order.symbol, "side": order.side.rawValue, "type": order.type.rawValue,
            "quantity": Self.plain(order.quantity),
            // The app's own execution price, so app-side pricing (and its defects) carry over.
            "referencePrice": Self.plain(order.type == .market ? order.executionPrice : order.referencePrice),
        ]
        if order.type == .limit { body["limitPrice"] = Self.plain(order.executionPrice) }
        return try JSONDecoder().decode(OrderDTO.self, from: try await write("/v1/orders", body)).model
    }

    private func write(_ path: String, _ body: [String: Any], key: String = UUID().uuidString) async throws -> Data {
        if condition == .offline { throw BackendError.offline }
        return try await call("POST", path, body: body, idempotencyKey: key)
    }

    private func read<T>(_ cached: () -> T, _ fetch: () async throws -> T) async -> T {
        do {
            return try await fetch()
        } catch {
            return cached()
        }
    }

    private func value(_ data: Data) throws -> Int {
        let v = try JSONDecoder().decode(CounterDTO.self, from: data).value
        counter = v
        return v
    }

    // MARK: - HTTP

    /// One API call in the app's session, signed in; signs in again once on a 401.
    private func call(_ method: String, _ path: String, body: [String: Any]? = nil,
                      idempotencyKey: String? = nil) async throws -> Data {
        try await ready()
        var reply = try await send(method, path, body: body, idempotencyKey: idempotencyKey)
        if reply.status == 401 {
            token = nil
            try await ready()
            reply = try await send(method, path, body: body, idempotencyKey: idempotencyKey)
        }
        if reply.status >= 400 { throw Self.problem(reply) }
        return reply.data
    }

    private func send(_ method: String, _ path: String, body: [String: Any]?, idempotencyKey: String?) async throws -> Reply {
        var headers: [String: String] = [:]
        if let sessionID { headers["X-Chaos-Session"] = sessionID }
        if let token { headers["Authorization"] = "Bearer \(token)" }
        if let idempotencyKey { headers["Idempotency-Key"] = idempotencyKey }
        return try await http(method, path, body: body, headers: headers)
    }

    /// Creates the session and signs in on first use; pushes pending defect / network changes.
    private func ready() async throws {
        if let setup { return try await setup.value }
        let task = Task { try await self.prepare() }
        setup = task
        defer { setup = nil }
        try await task.value
    }

    private func prepare() async throws {
        if serverDefects == nil {
            let catalog = try JSONDecoder().decode(CatalogDTO.self, from: try ok(await http("GET", "/chaos/catalog")))
            serverDefects = Set(catalog.defects.map(\.id))
        }
        if sessionID == nil {
            var body = sessionBody()
            body["seed"] = seed
            sessionID = try JSONDecoder().decode(SessionDTO.self, from: try ok(await http("POST", "/chaos/sessions", body: body))).id
            configDirty = false
        } else if configDirty, let sessionID {
            configDirty = false
            _ = try ok(await http("PUT", "/chaos/sessions/\(sessionID)", body: sessionBody()))
        }
        if token == nil, let sessionID {
            let headers = ["X-Chaos-Session": sessionID]
            let challenge = try JSONDecoder().decode(ChallengeDTO.self, from: try ok(await http(
                "POST", "/v1/auth/login", body: ["username": username, "password": "chaosbank"], headers: headers)))
            token = try JSONDecoder().decode(TokensDTO.self, from: try ok(await http(
                "POST", "/v1/auth/otp", body: ["challengeId": challenge.challengeId, "code": Self.demoOTP], headers: headers))).accessToken
        }
    }

    private func sessionBody() -> [String: Any] {
        let known = serverDefects ?? []
        let network: NetworkCondition = condition == .offline ? .normal : condition
        return ["defects": defects.map(\.rawValue).filter(known.contains).sorted(), "network": network.rawValue]
    }

    private struct Reply { let status: Int; let data: Data }

    private func ok(_ reply: Reply) throws -> Data {
        if reply.status >= 400 { throw Self.problem(reply) }
        return reply.data
    }

    private func http(_ method: String, _ path: String, body: [String: Any]? = nil,
                      headers: [String: String] = [:]) async throws -> Reply {
        var request = URLRequest(url: base.appending(path: path.components(separatedBy: "?")[0]))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        do {
            let (data, response) = try await session.data(for: request)
            return Reply(status: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
        } catch {
            throw BackendError.timeout
        }
    }

    /// A problem+json reply → the app's `BackendError`, by `type` first, then by status.
    private static func problem(_ reply: Reply) -> BackendError {
        let type = (try? JSONDecoder().decode(ProblemDTO.self, from: reply.data))?.type
        switch type {
        case "insufficientFunds": return .insufficientFunds
        case "unknownAccount": return .unknownAccount
        case "invalidAmount": return .invalidAmount
        case "unknownAsset": return .unknownAsset
        case "insufficientHolding": return .insufficientHolding
        case "timeout": return .timeout
        case "offline": return .offline
        default:
            switch reply.status {
            case 404: return .unknownAccount
            case 400..<500: return .invalidAmount
            default: return .timeout
            }
        }
    }

    /// Money on the wire is a plain decimal string ("4820.55"), never a binary double.
    private static func plain(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

// MARK: - Wire shapes (ChaosBank-Server openapi.yaml)

private nonisolated func decimal(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX")) ?? 0 }

private nonisolated struct AccountDTO: Decodable {
    let name: String, currency: String, balance: String
    var model: Account { Account(name: name, currency: Currency(rawValue: currency) ?? .EUR, balance: decimal(balance)) }
}

private nonisolated struct TransactionDTO: Decodable {
    let id: String, title: String, category: String, date: Int, amount: String, currency: String
    var model: Transaction {
        Transaction(id: id, title: title, category: category, date: Date(timeIntervalSince1970: TimeInterval(date)),
                    amount: decimal(amount), currency: Currency(rawValue: currency) ?? .EUR)
    }
}

private nonisolated struct PageDTO: Decodable { let items: [TransactionDTO] }

private nonisolated struct ExchangeDTO: Decodable { let transaction: TransactionDTO }

private nonisolated struct HoldingDTO: Decodable {
    let symbol: String, quantity: String, avgCost: String
    var model: Holding { Holding(symbol: symbol, quantity: decimal(quantity), avgCost: decimal(avgCost)) }
}

private nonisolated struct OrderDTO: Decodable {
    let id: String, symbol: String, side: String, type: String, quantity: String, limitPrice: String?
    let referencePrice: String, executionPrice: String, status: String, placedAt: Int
    var model: Order {
        Order(id: id, symbol: symbol, side: OrderSide(rawValue: side) ?? .buy, type: OrderType(rawValue: type) ?? .market,
              quantity: decimal(quantity), limitPrice: limitPrice.map(decimal), referencePrice: decimal(referencePrice),
              executionPrice: decimal(executionPrice), status: OrderStatus(rawValue: status) ?? .pending,
              placedAt: Date(timeIntervalSince1970: TimeInterval(placedAt)))
    }
}

private nonisolated struct CounterDTO: Decodable { let value: Int }
private nonisolated struct CatalogDTO: Decodable { struct Item: Decodable { let id: String }; let defects: [Item] }
private nonisolated struct SessionDTO: Decodable { let id: String }
private nonisolated struct ChallengeDTO: Decodable { let challengeId: String }
private nonisolated struct TokensDTO: Decodable { let accessToken: String }
private nonisolated struct ProblemDTO: Decodable { let type: String }
