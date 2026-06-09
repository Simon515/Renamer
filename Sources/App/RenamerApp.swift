import SwiftUI

@main
struct RenamerApp: App {
    @State private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 650)

        Settings {
            SettingsView()
        }
    }
}
