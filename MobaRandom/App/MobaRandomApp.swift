import SwiftUI

@main
struct MobaRandomApp: App {
    init() {
        AppBootstrap.applyBuiltInWeightPresetIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(.blue)
        }
    }
}

