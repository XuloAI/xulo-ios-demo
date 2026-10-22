import Foundation
import UIKit
import Xulo

@MainActor
final class DemoModel: ObservableObject {
    static let serviceURL = URL(string: "https://xulo.io")!
    @Published var appId: String
    @Published var externalId: String
    @Published var tagKey: String
    @Published var tagValue: String
    @Published var amount: String
    @Published var currency: String
    @Published var orderId: String
    @Published var callName: String
    @Published var pushURL: String
    @Published var draftId: String
    @Published var handleLink: Bool
    @Published var crashesEnabled: Bool
    @Published var token = "No token yet"
    @Published var xuloId = "Not yet"
    @Published var lastOpen = "No push opened yet."
    @Published var log: [String] = []
    @Published var checks: [DemoCheck] = []
    @Published var runningChecks = false

    let bundleId = Bundle.main.bundleIdentifier ?? "app.xulo.demo"
    let appGroup = "group.app.xulo.demo"
    let sdkVersion = Xulo.sdkVersion

    var subscriptionId: String { Xulo.subscriptionId }
    var language: String { Locale.preferredLanguages.first ?? "None" }
    var timezone: String { TimeZone.current.identifier }
    var country: String {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier ?? "None"
        }
        return Locale.current.regionCode ?? "None"
    }
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    init() {
        let defaults = UserDefaults.standard
        appId = defaults.string(forKey: "xulo.appId") ?? ""
        externalId = defaults.string(forKey: "xulo.external") ?? "demo-user"
        tagKey = "plan"
        tagValue = "demo"
        amount = "100"
        currency = "USD"
        orderId = "order-1"
        callName = "demo"
        pushURL = "https://example.com/match"
        draftId = ""
        handleLink = false
        crashesEnabled = true
        bindOpen()
    }

    func start() {
        let id = appId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            note("Paste the App ID.")
            return
        }
        UserDefaults.standard.set(id, forKey: "xulo.appId")
        Xulo.crashesEnabled = crashesEnabled
        bindOpen()
        Xulo.start(appId: id, bundleId: bundleId)
        note("Started. A session is open while the app is in front.")
        refreshLater()
    }

    func requestPush() {
        Xulo.requestPushPermission()
        note("Asked for push permission.")
    }

    func login() {
        let id = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            note("External ID is empty.")
            return
        }
        UserDefaults.standard.set(id, forKey: "xulo.external")
        Task {
            await Xulo.login(externalId: id)
            xuloId = Xulo.xuloId ?? "Not yet"
            note("Logged in as \(id).")
        }
    }

    func logout() {
        Task {
            await Xulo.logout()
            xuloId = Xulo.xuloId ?? "Not yet"
            note("Logged out. The subscription id stayed.")
        }
    }

    func saveTags() {
        let key = tagKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = tagValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            note("Tag key is empty.")
            return
        }
        Xulo.setTags([key: value])
        note("Tag saved. It replaces the previous set.")
    }

    func sendPurchase() {
        guard let cents = Int(amount.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            note("Amount has to be a whole number.")
            return
        }
        let code = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            note("Currency is empty.")
            return
        }
        let order = orderId.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await Xulo.purchase(amount: cents, currency: code, orderId: order.isEmpty ? nil : order)
            note(order.isEmpty ? "Purchase sent." : "Purchase \(order) sent. The same order replaces the amount.")
        }
    }

    func showCard() {
        let name = callName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            note("Call name is empty.")
            return
        }
        Xulo.call(name)
        note("Asked for a card named \(name).")
    }

    func simulatePush() {
        let url = pushURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var extra: [String: Any] = ["source": "demo"]
        let raw = draftId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            extra["draft_id"] = raw
        }
        var custom: [String: Any] = ["a": extra]
        if !url.isEmpty { custom["u"] = url }
        Xulo.didReceive(userInfo: ["custom": custom])
        note("Local push open sent.")
    }

    func report(_ failure: String) {
        Xulo.crashesEnabled = crashesEnabled
        Xulo.reportFailure(failure)
        note("Reported \(failure).")
    }

    func setCrashes(_ enabled: Bool) {
        crashesEnabled = enabled
        Xulo.crashesEnabled = enabled
        note(enabled ? "Crash reports are on." : "Crash reports are off.")
    }

    func copySubscription() {
        UIPasteboard.general.string = subscriptionId
        note("Subscription id copied.")
    }

    func runChecks() {
        guard !runningChecks else { return }
        runningChecks = true
        checks = DemoSuite.titles.map { DemoCheck(id: $0.0, title: $0.1, mark: .waiting, detail: "") }
        Task {
            await DemoSuite.run(self)
            runningChecks = false
            note("Checks finished.")
        }
    }

    func finish(_ id: String, passed: Bool, detail: String, note markAsNote: Bool = false) {
        guard let index = checks.firstIndex(where: { $0.id == id }) else { return }
        var check = checks[index]
        check.mark = markAsNote ? .note : (passed ? .pass : .fail)
        check.detail = detail
        checks[index] = check
    }

    func skipRest(after id: String) {
        guard let start = checks.firstIndex(where: { $0.id == id }) else { return }
        for index in checks.indices where index > start && checks[index].mark == .waiting {
            var check = checks[index]
            check.mark = .fail
            check.detail = "Did not run."
            checks[index] = check
        }
    }

    func note(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 12 { log.removeLast() }
    }

    private func bindOpen() {
        Xulo.onOpen = { [weak self] url, extra in
            let lines = Self.describe(url: url, extra: extra)
            let handled = self?.handleLink ?? false
            Task { @MainActor in
                self?.lastOpen = lines
                self?.note(handled ? "App handled the push link." : "Push link left to the system when it is https.")
            }
            return handled
        }
    }

    private func refreshLater() {
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            xuloId = Xulo.xuloId ?? "Not yet"
        }
    }

    private static func describe(url: URL?, extra: [String: Any]) -> String {
        var lines: [String] = []
        lines.append(url?.absoluteString ?? "No URL")
        let pairs = extra.keys.sorted().map { key in "\(key): \(extra[key] ?? "")" }
        if pairs.isEmpty {
            lines.append("No extra")
        } else {
            lines.append(contentsOf: pairs)
        }
        return lines.joined(separator: "\n")
    }
}
