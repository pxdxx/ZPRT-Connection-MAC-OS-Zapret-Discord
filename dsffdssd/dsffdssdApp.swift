import SwiftUI

@main
struct dsffdssdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .onAppear {
                    // AppDelegate.applicationDidFinishLaunching runs before @State
                    // is wired — bootstrap must happen here so install/running
                    // status is restored after relaunch instead of showing "not installed".
                    let needsBootstrap = appDelegate.state !== state
                    appDelegate.state = state
                    if needsBootstrap {
                        state.bootstrap()
                    } else {
                        state.refreshStatus()
                    }
                    appDelegate.refreshTray()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: OutpostDimens.windowWidth, height: OutpostDimens.windowHeight)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("ZPRT") {
                Button("Показать окно") {
                    appDelegate.showMainWindow()
                }
                Divider()
                Button(state.running ? "Выключить" : "Включить") {
                    Task { await state.togglePower() }
                }
                .disabled(state.busy != nil)
            }
        }
    }
}
