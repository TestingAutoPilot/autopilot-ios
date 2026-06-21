import SwiftUI

@main
struct TestHostAppApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .navigationTitle("TestHostApp")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
