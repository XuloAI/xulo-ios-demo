import Foundation
import Xulo

struct DemoCheck: Identifiable {
    var id: String
    var title: String
    var mark: Mark
    var detail: String

    enum Mark {
        case waiting
        case pass
        case fail
        case note
    }
}

struct DemoReply {
    var status: Int
    var json: [String: Any]

    var ok: Bool { (200..<300).contains(status) }
}

enum DemoHTTP {
    static func post(base: URL, key: String, bundle: String, path: String, body: [String: Any]) async -> DemoReply {
        let root = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encoded = bundle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bundle
        guard let url = URL(string: "\(root)/api/v1/apps/\(encoded)/\(path)"),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            return DemoReply(status: 0, json: [:])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(key, forHTTPHeaderField: "X-Xulo-App-Id")
        do {
            let (payload, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: payload) as? [String: Any]) ?? [:]
            return DemoReply(status: status, json: json)
        } catch {
            return DemoReply(status: 0, json: ["message": error.localizedDescription])
        }
    }
}

@MainActor
enum DemoSuite {
    static let titles: [(String, String)] = [
        ("register", "Register"),
        ("number", "Numeric external ID"),
        ("blank", "Blank external ID stays logged in"),
        ("login", "Log in"),
        ("tags", "Tags"),
        ("open", "Open"),
        ("session", "Session counted once"),
        ("event", "Event"),
        ("purchase", "Same order replaces the amount"),
        ("refund", "Refund"),
        ("card", "In-app card"),
        ("report", "Failure report"),
        ("identity", "Report rejects identity"),
        ("push", "Push open"),
        ("logout", "Log out keeps the subscription"),
        ("token", "Push token"),
        ("image", "Image push"),
    ]

    static func run(_ model: DemoModel) async {
        let base = DemoModel.serviceURL
        let key = model.appId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            model.finish("register", passed: false, detail: "Paste the App ID, then run again.")
            model.skipRest(after: "register")
            return
        }
        model.start()
        let subscription = model.subscriptionId
        let appeared = await waitForXuloId()
        model.finish("register", passed: appeared && isUUID(subscription), detail: appeared ? subscription : "The server did not return a Xulo ID.")
        guard appeared else {
            model.skipRest(after: "register")
            return
        }

        let numbered = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "devices", body: [
            "subscription_id": subscription,
            "external_id": 5,
        ])
        model.finish("number", passed: numbered.ok, detail: numbered.ok ? "5 was accepted." : failure(numbered))

        let blank = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "devices", body: [
            "subscription_id": subscription,
            "external_id": "   ",
        ])
        model.finish("blank", passed: blank.ok, detail: blank.ok ? "Whitespace did not log the device out." : failure(blank))

        await Xulo.login(externalId: model.externalId)
        model.xuloId = Xulo.xuloId ?? "Not yet"
        let loggedIn = Xulo.xuloId != nil
        model.finish("login", passed: loggedIn, detail: loggedIn ? (Xulo.xuloId ?? "") : "Log in did not return a Xulo ID.")

        Xulo.setTags([model.tagKey: model.tagValue])
        let tags = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "devices", body: [
            "subscription_id": subscription,
            "tags": [model.tagKey: model.tagValue],
        ])
        model.finish("tags", passed: tags.ok, detail: tags.ok ? "\(model.tagKey)=\(model.tagValue)" : failure(tags))

        let opened = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "open", body: [
            "subscription_id": subscription,
            "timezone": model.timezone,
            "language": model.language,
        ])
        model.finish("open", passed: opened.ok && opened.json["last_opened_at"] != nil, detail: opened.ok ? "Last open recorded." : failure(opened))

        let sessionId = UUID().uuidString.lowercased()
        let started = iso(Date())
        let ended = iso(Date().addingTimeInterval(50))
        let sessionBody: [String: Any] = [
            "subscription_id": subscription,
            "session_id": sessionId,
            "started_at": started,
            "ended_at": ended,
        ]
        let firstSession = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "sessions", body: sessionBody)
        let secondSession = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "sessions", body: sessionBody)
        let sameDuration = number(firstSession.json["duration_seconds"]) == number(secondSession.json["duration_seconds"])
        model.finish("session", passed: firstSession.ok && secondSession.ok && sameDuration, detail: sameDuration ? "Second post kept the first duration." : failure(secondSession))

        let eventId = UUID().uuidString.lowercased()
        let eventBody: [String: Any] = [
            "subscription_id": subscription,
            "events": [[
                "id": eventId,
                "type": "impressed",
                "channel": "in_app",
            ]],
        ]
        let event = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "events", body: eventBody)
        let again = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "events", body: eventBody)
        model.finish("event", passed: event.ok && again.ok, detail: event.ok ? "The same event id was accepted again." : failure(event))

        let order = "demo-\(Int(Date().timeIntervalSince1970))"
        await Xulo.purchase(amount: 100, currency: "usd", orderId: order)
        let bought = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "purchases", body: [
            "subscription_id": subscription,
            "amount": 100,
            "currency": "usd",
            "order_id": order,
        ])
        let replaced = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "purchases", body: [
            "subscription_id": subscription,
            "amount": 40,
            "currency": "usd",
            "order_id": order,
        ])
        let samePurchase = number(bought.json["id"]) == number(replaced.json["id"]) && bought.ok && replaced.ok
        model.finish("purchase", passed: samePurchase, detail: samePurchase ? "Order \(order) stayed on one row." : failure(replaced))

        if samePurchase, let purchaseId = number(bought.json["id"]) {
            let refund = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "purchases/\(purchaseId)/refund", body: [:])
            model.finish("refund", passed: refund.ok && refund.json["refunded_at"] != nil, detail: refund.ok ? "Refund recorded." : failure(refund))
        } else {
            model.finish("refund", passed: false, detail: "Purchase did not return an id.")
        }

        Xulo.call(model.callName)
        let card = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "cards", body: [
            "subscription_id": subscription,
            "call_name": model.callName,
        ])
        let title = (card.json["card"] as? [String: Any])?["title"] as? String
        model.finish("card", passed: card.ok, detail: card.ok ? (title ?? "No card is waiting.") : failure(card))

        Xulo.crashesEnabled = true
        Xulo.reportFailure("image_failed")
        let report = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "reports", body: [
            "kind": "failure",
            "sdk_version": model.sdkVersion,
            "failure": "card_failed",
        ])
        model.finish("report", passed: report.ok, detail: report.ok ? "card_failed accepted." : failure(report))

        let leaked = await DemoHTTP.post(base: base, key: key, bundle: model.bundleId, path: "reports", body: [
            "kind": "crash",
            "sdk_version": model.sdkVersion,
            "subscription_id": subscription,
        ])
        model.finish("identity", passed: leaked.status == 422, detail: leaked.status == 422 ? "Identity was refused." : failure(leaked))

        model.handleLink = true
        model.simulatePush()
        try? await Task.sleep(nanoseconds: 200_000_000)
        let sawLink = model.lastOpen.contains(model.pushURL)
        model.finish("push", passed: sawLink, detail: sawLink ? "custom.u and custom.a reached the app." : model.lastOpen)

        let before = model.subscriptionId
        await Xulo.logout()
        model.xuloId = Xulo.xuloId ?? "Not yet"
        let kept = model.subscriptionId == before && Xulo.xuloId != nil
        model.finish("logout", passed: kept, detail: kept ? "Subscription id did not change." : "Subscription id changed.")

        let tokenReady = model.token.count > 20 && model.token.allSatisfy(\.isHexDigit)
        model.finish("token", passed: tokenReady, detail: tokenReady ? "Token is on this device." : "Tap Allow push on a phone, then run again.", note: !tokenReady)
        model.finish("image", passed: true, detail: "Send an image push from the panel to \(subscription).", note: true)
    }

    private static func waitForXuloId() async -> Bool {
        for _ in 0..<12 {
            if Xulo.xuloId != nil { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return Xulo.xuloId != nil
    }

    private static func isUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    private static func number(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func failure(_ reply: DemoReply) -> String {
        let message = reply.json["message"] as? String ?? "HTTP \(reply.status)"
        return message
    }
}
