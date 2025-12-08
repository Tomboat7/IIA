import SwiftUI

/// iPad Illustration App のエントリポイント
@main
struct IIAApp: App {
    @StateObject private var documentManager = DocumentManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(documentManager)
        }
    }
}
