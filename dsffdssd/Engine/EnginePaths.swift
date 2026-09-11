import Foundation

enum EnginePaths {
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

    private static func ifconfigExists(_ iface: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        task.arguments = [iface]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    private static func launchdIsRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["print", "system/\(daemonLabel)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return false }
        let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return text.contains("state = running")
    }
}

struct CommandResult: Sendable {
    let ok: Bool
    let output: String
    var warning: String?

    var lastLine: String {
        output.split(whereSeparator: \.isNewline).last.map(String.init) ?? output
    }
}

enum EngineError: LocalizedError {
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
