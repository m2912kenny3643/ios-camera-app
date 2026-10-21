import SwiftUI

@main
struct EOSR6MarkIIIApp: App {
    var body: some Scene {
        WindowGroup {
            MainCameraView()
                .statusBar(hidden: true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
