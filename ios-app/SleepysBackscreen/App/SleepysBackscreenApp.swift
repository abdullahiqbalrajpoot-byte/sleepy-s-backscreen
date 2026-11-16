import SwiftUI

@main
struct SleepysBackscreenApp: App {
    init() {
        // Initialize BLE Manager and Music Observer
        _ = BLEManager.shared
        _ = MusicObserver.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
