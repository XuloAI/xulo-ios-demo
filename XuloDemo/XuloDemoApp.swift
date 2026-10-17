import SwiftUI
import Xulo

@main
struct XuloDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = DemoModel()

    var body: some Scene {
        WindowGroup {
            DemoView(model: model)
                .onAppear { delegate.model = model }
        }
    }
}
