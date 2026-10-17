import SwiftUI

struct DemoView: View {
    @ObservedObject var model: DemoModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    connection
                    checks
                    device
                    person
                    tags
                    purchase
                    card
                    push
                    crashes
                    activity
                }
                .padding(20)
            }
            .background(Color(red: 243 / 255, green: 243 / 255, blue: 244 / 255).ignoresSafeArea())
            .navigationTitle("Xulo Demo")
        }
        .navigationViewStyle(.stack)
    }

    private var connection: some View {
        Card(title: "Connection") {
            Field(title: "Organization API key", text: $model.apiKey)
            DemoButton(title: "Start") { model.start() }
        }
    }

    private var checks: some View {
        Card(title: "Checks") {
            Text("Runs register, login, tags, open, session, event, purchase, refund, card, reports, push open, and logout against this API.")
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            DemoButton(title: model.runningChecks ? "Running…" : "Run all checks") {
                model.runChecks()
            }
            .disabled(model.runningChecks)
            if model.checks.isEmpty {
                Text("Nothing has run yet.")
                    .font(.system(size: 14))
                    .foregroundColor(DemoColor.mute)
            } else {
                ForEach(model.checks) { check in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(label(check.mark))  \(check.title)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DemoColor.ink)
                        if !check.detail.isEmpty {
                            Text(check.detail)
                                .font(.system(size: 13))
                                .foregroundColor(DemoColor.mute)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func label(_ mark: DemoCheck.Mark) -> String {
        switch mark {
        case .waiting: return "…"
        case .pass: return "Pass"
        case .fail: return "Fail"
        case .note: return "Look"
        }
    }

    private var device: some View {
        Card(title: "Device") {
            Fact(title: "Bundle id", value: model.bundleId)
            Fact(title: "App group", value: model.appGroup)
            Fact(title: "SDK", value: model.sdkVersion)
            Fact(title: "Language", value: model.language)
            Fact(title: "Timezone", value: model.timezone)
            Fact(title: "Country", value: model.country)
            Fact(title: "App version", value: model.appVersion)
            Fact(title: "Subscription id", value: model.subscriptionId)
            Button("Copy subscription id") { model.copySubscription() }
                .font(.system(size: 15, weight: .semibold))
            Fact(title: "Xulo id", value: model.xuloId)
            Fact(title: "Push token", value: model.token)
            Text("A session starts in the foreground and ends in the background. A return within 30 seconds continues it.")
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            DemoButton(title: "Allow push") { model.requestPush() }
        }
    }

    private var person: some View {
        Card(title: "Person") {
            Field(title: "External ID", text: $model.externalId)
            DemoButton(title: "Log in") { model.login() }
            QuietButton(title: "Log out") { model.logout() }
        }
    }

    private var tags: some View {
        Card(title: "Tags") {
            Field(title: "Key", text: $model.tagKey)
            Field(title: "Value", text: $model.tagValue)
            Text("Saving replaces the tag set.")
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            DemoButton(title: "Save tags") { model.saveTags() }
        }
    }

    private var purchase: some View {
        Card(title: "Purchase") {
            Field(title: "Amount", text: $model.amount)
            Field(title: "Currency", text: $model.currency)
            Field(title: "Order id", text: $model.orderId)
            DemoButton(title: "Send purchase") { model.sendPurchase() }
        }
    }

    private var card: some View {
        Card(title: "In-app") {
            Text("Opening the app asks for a card. A named call asks again on the same request.")
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            Field(title: "Call name", text: $model.callName)
            DemoButton(title: "Call") { model.showCard() }
        }
    }

    private var push: some View {
        Card(title: "Push") {
            Text("Create the panel app with bundle id \(model.bundleId). A real push uses category xulo, so the expanded view can draw.")
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            Toggle("Handle the link in the app", isOn: $model.handleLink)
                .font(.system(size: 15))
            Text(model.lastOpen)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(DemoColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Field(title: "Simulated URL", text: $model.pushURL)
            Field(title: "Draft id", text: $model.draftId)
            QuietButton(title: "Simulate a push open") { model.simulatePush() }
        }
    }

    private var crashes: some View {
        Card(title: "Reports") {
            Toggle("Send crash reports", isOn: Binding(
                get: { model.crashesEnabled },
                set: { model.setCrashes($0) }
            ))
            .font(.system(size: 15))
            Text("These three are not crashes. They show up on the overview.")
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            QuietButton(title: "Report token rejected") { model.report("token_rejected") }
            QuietButton(title: "Report image failed") { model.report("image_failed") }
            QuietButton(title: "Report card failed") { model.report("card_failed") }
        }
    }

    private var activity: some View {
        Card(title: "Activity") {
            if model.log.isEmpty {
                Text("Nothing yet.")
                    .font(.system(size: 14))
                    .foregroundColor(DemoColor.mute)
            } else {
                ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundColor(DemoColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct Card<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DemoColor.ink)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }
}

private struct Field: View {
    var title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }
}

private struct Fact: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(DemoColor.mute)
            Text(value)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(DemoColor.ink)
                .textSelection(.enabled)
        }
    }
}

private struct DemoButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DemoColor.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
    }
}

private struct QuietButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 243 / 255, green: 243 / 255, blue: 244 / 255))
                .foregroundColor(DemoColor.ink)
                .cornerRadius(12)
        }
    }
}

private enum DemoColor {
    static let ink = Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255)
    static let mute = Color(red: 94 / 255, green: 94 / 255, blue: 94 / 255)
    static let blue = Color(red: 47 / 255, green: 107 / 255, blue: 1)
}
