import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var state: AppState?
    private var statusItem: NSStatusItem?
    private var trayObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupTray()
        trayObserver = NotificationCenter.default.addObserver(
            forName: .outpostTrayNeedsRefresh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshTray()
        }
        // state is wired from the SwiftUI scene's onAppear (after @State exists).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.attachWindowDelegateIfNeeded()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        refreshTray()
        return false
    }

    func setupTray() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = TrayIconFactory.image(active: state?.running == true)
            button.image?.isTemplate = true
            button.toolTip = "ZPRT Connection"
            button.target = self
            button.action = #selector(trayPrimaryClick)
        }
        statusItem = item
        rebuildMenu()
    }

    func refreshTray() {
        statusItem?.button?.image = TrayIconFactory.image(active: state?.running == true)
        statusItem?.button?.image?.isTemplate = true
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let state else { return }
        let menu = NSMenu()

        let status = NSMenuItem(title: trayStatusTitle(state), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if !state.installed {
            menu.addItem(item("Установить движок", #selector(trayInstall), enabled: state.busy == nil))
        } else if state.running {
            menu.addItem(item("Выключить", #selector(trayToggle), enabled: state.busy == nil))
        } else {
            menu.addItem(item("Включить", #selector(trayToggle), enabled: state.busy == nil))
        }

        menu.addItem(.separator())
        menu.addItem(item("Открыть окно", #selector(trayOpen)))
        menu.addItem(item("Studio", #selector(traySettings)))
        menu.addItem(.separator())
        menu.addItem(item("Закрыть полностью", #selector(trayQuit)))
        statusItem?.menu = menu
    }

    private func trayStatusTitle(_ state: AppState) -> String {
        if let busy = state.busy { return busy }
        if !state.installed { return "Не установлен" }
        return state.running ? "Работает" : "Остановлено"
    }

    private func item(_ title: String, _ action: Selector, enabled: Bool = true) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        i.isEnabled = enabled
        return i
    }

    @objc private func trayPrimaryClick() { showMainWindow() }
    @objc private func trayToggle() { Task { await state?.togglePower() } }
    @objc private func trayInstall() { Task { await state?.installEngine() } }
    @objc private func trayOpen() {
        showMainWindow()
        state?.show(.home)
    }
    @objc private func traySettings() {
        showMainWindow()
        state?.show(.settings)
    }
    @objc private func trayQuit() { NSApp.terminate(nil) }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        attachWindowDelegateIfNeeded()
        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        refreshTray()
    }

    private func attachWindowDelegateIfNeeded() {
        for window in NSApp.windows where window.canBecomeKey {
            window.delegate = self
            window.title = "ZPRT Connection"
        }
    }
}

extension Notification.Name {
    static let outpostTrayNeedsRefresh = Notification.Name("outpostTrayNeedsRefresh")
}

enum TrayIconFactory {
    static func image(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset: CGFloat = 1.4
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset))
            ring.lineWidth = 1.7
            NSColor.black.setStroke()
            ring.stroke()

            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: rect.minX + 4.8, y: rect.maxY - 4.8))
            slash.line(to: NSPoint(x: rect.maxX - 4.8, y: rect.minY + 4.8))
            slash.lineWidth = 1.7
            slash.lineCapStyle = .round
            slash.stroke()

            let body = NSBezierPath(
                roundedRect: NSRect(x: rect.midX - 3.6, y: rect.midY - 2.2, width: 7.2, height: 4.4),
                xRadius: 1.4,
                yRadius: 1.4
            )
            if active {
                NSColor.black.setFill()
                body.fill()
            } else {
                body.lineWidth = 1.1
                body.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
