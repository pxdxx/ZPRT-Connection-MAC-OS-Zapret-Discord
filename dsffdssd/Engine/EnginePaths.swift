import Foundation

nonisolated enum EnginePaths {
    static let daemonLabel = "org.zapret.macos.engine"
    static let systemRoot = URL(fileURLWithPath: "/Library/Application Support/Zapret")
    static let launchDaemon = URL(fileURLWithPath: "/Library/LaunchDaemons/\(daemonLabel).plist")
    static let utunws = systemRoot.appendingPathComponent("bin/utunws")
    static let stopScript = systemRoot.appendingPathComponent("stop.sh")
    static let restartScript = systemRoot.appendingPathComponent("restart.sh")
    static let installScript = systemRoot.appendingPathComponent("install.sh")
    static let uninstallScript = systemRoot.appendingPathComponent("uninstall.sh")

    static var userDataRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Zapret")
    }

    static var selectedStrategyFile: URL { userDataRoot.appendingPathComponent("selected-strategy") }
    static var ipsetModeFile: URL { userDataRoot.appendingPathComponent("ipset-mode") }
    static var discordUdpFile: URL { userDataRoot.appendingPathComponent("discord-udp") }
    static var blockQuicFile: URL { userDataRoot.appendingPathComponent("block-quic") }
    static var fastKeepinitFile: URL { userDataRoot.appendingPathComponent("fast-keepinit") }
    static var gameFilterFile: URL { userDataRoot.appendingPathComponent("game-filter") }
    static var listsDir: URL { userDataRoot.appendingPathComponent("lists") }
    static var prefsFile: URL { userDataRoot.appendingPathComponent("zprt-prefs.json") }

    static var bundledPayload: URL? {
        // Prefer reconstructed payload; fall back to nested engine/ if present.
        let staged = EngineBundle.stagingRoot
        if FileManager.default.fileExists(atPath: staged.appendingPathComponent("run.sh").path) {
            return staged
        }
        if let nested = Bundle.main.resourceURL?.appendingPathComponent("engine"),
           FileManager.default.fileExists(atPath: nested.appendingPathComponent("run.sh").path) {
            return nested
        }
        // Flat resources can still seed lists/strategies before materialize()
        return Bundle.main.resourceURL
    }

    static var isInstalled: Bool {
        let fm = FileManager.default
        let hasBinary = fm.fileExists(atPath: utunws.path)
            || fm.isExecutableFile(atPath: utunws.path)
        let hasPlist = fm.fileExists(atPath: launchDaemon.path)
        let hasRun = fm.fileExists(atPath: systemRoot.appendingPathComponent("run.sh").path)
        // Files remain after PAUSE (stop.sh bootouts the daemon but keeps the install).
        return hasBinary && (hasPlist || hasRun)
    }

    static var isRunning: Bool {
        // Prefer utun50 (created by utunws when healthy); fall back to launchd state.
        if ifconfigExists("utun50") { return true }
        return launchdIsRunning()
    }

    // These used to spawn Process()+waitUntilExit() directly with no timeout and an
    // unread output pipe — if launchctl ever wrote enough output to fill the pipe
    // buffer with nobody draining it, the child would block on write and
    // waitUntilExit() would hang forever (the exact "hangs out of nowhere after a
    // while" reports). Shell.run() already handles this safely with a timeout and
    // a forced terminate, so route through it instead.
    private static func ifconfigExists(_ iface: String) -> Bool {
        Shell.run(["/sbin/ifconfig", iface], timeoutSeconds: 5).ok
    }

    private static func launchdIsRunning() -> Bool {
        let result = Shell.run(["/bin/launchctl", "print", "system/\(daemonLabel)"], timeoutSeconds: 5)
        guard result.ok else { return false }
        return result.output.contains("state = running")
    }
}

nonisolated struct CommandResult: Sendable {
    let ok: Bool
    let output: String
    var warning: String?

    var lastLine: String {
        output.split(whereSeparator: \.isNewline).last.map(String.init) ?? output
    }
}

nonisolated enum EngineError: LocalizedError {
    case cancelled
    case missingPayload
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: "Запрос прав администратора отменён"
        case .missingPayload: "Пакет двигателя не найден в приложении"
        case .failed(let message): message
        }
    }
}
