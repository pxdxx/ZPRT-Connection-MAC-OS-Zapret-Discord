import Foundation

/// The project defaults every unmarked type to @MainActor isolation
/// (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor). Without `nonisolated` here,
/// every call into this enum — including from inside Task.detached — got
/// silently hopped back onto the main actor, so the blocking Process/osascript
/// calls inside (install/start/stop/uninstall, ifconfig/launchctl checks)
/// always ran on the main thread regardless of the detached wrapper. That's
/// the real cause of the app freezing on GO and on the status poll.
nonisolated enum EngineService {
    static func refreshPrerequisites() -> Prerequisites {
        let resources = Bundle.main.resourceURL
        let hasBinary = resources.map {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("utunws").path)
                || FileManager.default.isExecutableFile(atPath: $0.appendingPathComponent("bin/utunws").path)
        } ?? false
        let hasSources = resources.map {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("run.sh").path)
                || FileManager.default.fileExists(atPath: $0.appendingPathComponent("strategies.tsv").path)
        } ?? false
        let wan = primaryWanInterface()
        let installed = EnginePaths.isInstalled
        let passwordless = FileManager.default.fileExists(atPath: "/etc/sudoers.d/zapret")
            || FileManager.default.fileExists(atPath: "/etc/sudoers.d/zapret2")
        return Prerequisites(
            hasSources: hasSources,
            hasPrebuiltBinary: hasBinary,
            hasCompiler: true,
            wanInterface: wan,
            engineInstalled: installed,
            passwordlessReady: passwordless || !installed
        )
    }

    static func loadStrategies() -> [StrategyEntry] {
        let candidates = [
            EngineBundle.stagingRoot.appendingPathComponent("strategies.tsv"),
            Bundle.main.resourceURL?.appendingPathComponent("strategies.tsv"),
            Bundle.main.resourceURL?.appendingPathComponent("engine/strategies.tsv"),
        ].compactMap { $0 }
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return .bundled
        }
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return StrategyEntry(id: parts[0], title: parts[1].uppercased(), detail: parts[0])
        }
    }

    static func ensureUserDataSeeded(defaultsFromPayload: Bool = true) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: EnginePaths.listsDir, withIntermediateDirectories: true)
        if defaultsFromPayload {
            let defaultDirs: [URL] = [
                EngineBundle.stagingRoot.appendingPathComponent("default-lists"),
                Bundle.main.resourceURL,
            ].compactMap { $0 }
            for defaults in defaultDirs {
                for file in ListFile.allCases {
                    let dest = EnginePaths.listsDir.appendingPathComponent(file.rawValue)
                    let alreadyExists = fm.fileExists(atPath: dest.path)

                    if file.isUserManaged {
                        if alreadyExists {
                            if file == .generalUser {
                                try migrateDiscordDefaultsIfNeeded(dest: dest, defaultsRoot: defaults)
                            }
                            continue
                        }
                    }

                    let src = defaults.appendingPathComponent(file.rawValue)
                    if fm.fileExists(atPath: src.path) {
                        guard let content = try? String(contentsOf: src, encoding: .utf8) else { continue }
                        if alreadyExists,
                           let current = try? String(contentsOf: dest, encoding: .utf8),
                           current == content {
                            continue
                        }
                        try content.write(to: dest, atomically: true, encoding: .utf8)
                    } else if !alreadyExists, !file.defaultContent.isEmpty {
                        try file.defaultContent.write(to: dest, atomically: true, encoding: .utf8)
                    }
                }
            }
        }
        if !fm.fileExists(atPath: EnginePaths.selectedStrategyFile.path) {
            try "general-simple-fake".write(to: EnginePaths.selectedStrategyFile, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: EnginePaths.ipsetModeFile.path) {
            try "loaded".write(to: EnginePaths.ipsetModeFile, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: EnginePaths.discordUdpFile.path) {
            try "1".write(to: EnginePaths.discordUdpFile, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: EnginePaths.blockQuicFile.path) {
            try "1".write(to: EnginePaths.blockQuicFile, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: EnginePaths.fastKeepinitFile.path) {
            try "1".write(to: EnginePaths.fastKeepinitFile, atomically: true, encoding: .utf8)
        }
        if !fm.fileExists(atPath: EnginePaths.gameFilterFile.path) {
            try gameFilterFileText(.default).write(to: EnginePaths.gameFilterFile, atomically: true, encoding: .utf8)
        }
    }

    /// Installs from before the Discord starter list existed already have a
    /// generalUser file on disk, so the "only seed if missing" rule above
    /// would never give them the pre-filled domains. Top it up in place,
    /// once, without touching anything the user already added.
    private static func migrateDiscordDefaultsIfNeeded(dest: URL, defaultsRoot: URL) throws {
        let existing = (try? String(contentsOf: dest, encoding: .utf8)) ?? ""
        guard !existing.lowercased().contains("discord.com") else { return }
        let starterURL = defaultsRoot.appendingPathComponent(ListFile.generalUser.rawValue)
        let starter = (try? String(contentsOf: starterURL, encoding: .utf8)) ?? ListFile.generalUser.defaultContent
        guard !starter.isEmpty else { return }
        var merged = starter
        if !merged.hasSuffix("\n") { merged += "\n" }
        if !existing.isEmpty {
            merged += "\n" + existing
        }
        try merged.write(to: dest, atomically: true, encoding: .utf8)
    }

    static func readConfig() -> EngineConfig {
        let strategy = (try? String(contentsOf: EnginePaths.selectedStrategyFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? EngineConfig.default.strategyId
        let modeRaw = (try? String(contentsOf: EnginePaths.ipsetModeFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "loaded"
        let mode = IpsetMode(rawValue: modeRaw) ?? .loaded
        let discord = ((try? String(contentsOf: EnginePaths.discordUdpFile, encoding: .utf8)) ?? "1")
            .trimmingCharacters(in: .whitespacesAndNewlines) != "0"
        let quic = ((try? String(contentsOf: EnginePaths.blockQuicFile, encoding: .utf8)) ?? "1")
            .trimmingCharacters(in: .whitespacesAndNewlines) != "0"
        let fastKeepinit = ((try? String(contentsOf: EnginePaths.fastKeepinitFile, encoding: .utf8)) ?? "1")
            .trimmingCharacters(in: .whitespacesAndNewlines) != "0"
        var config = EngineConfig(strategyId: strategy, ipsetMode: mode, discordUdp: discord, blockQuic: quic, fastKeepinit: fastKeepinit)
        let game = readGameFilterValues()
        config.gameFilter = GameFilterMode(rawValue: game["mode", default: ""]) ?? .disabled
        if let tcp = game["tcp"], GameFilterMode.isValidPorts(tcp) { config.gameTcpPorts = tcp }
        if let udp = game["udp"], GameFilterMode.isValidPorts(udp) { config.gameUdpPorts = udp }
        return config
    }

    private static func readGameFilterValues() -> [String: String] {
        let text = (try? String(contentsOf: EnginePaths.gameFilterFile, encoding: .utf8)) ?? ""
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let pair = line.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            values[pair[0].trimmingCharacters(in: .whitespaces)] = pair[1].filter { !$0.isWhitespace }
        }
        return values
    }

    private static func gameFilterFileText(_ config: EngineConfig) -> String {
        // An invalid range would make run.sh fall back to the default, so store what will really apply.
        let tcp = GameFilterMode.isValidPorts(config.gameTcpPorts) ? config.gameTcpPorts.filter { !$0.isWhitespace } : GameFilterMode.defaultPorts
        let udp = GameFilterMode.isValidPorts(config.gameUdpPorts) ? config.gameUdpPorts.filter { !$0.isWhitespace } : GameFilterMode.defaultPorts
        return "mode=\(config.gameFilter.rawValue)\ntcp=\(tcp)\nudp=\(udp)\n"
    }

    static func writeConfig(_ config: EngineConfig) throws {
        try ensureUserDataSeeded(defaultsFromPayload: false)
        try config.strategyId.write(to: EnginePaths.selectedStrategyFile, atomically: true, encoding: .utf8)
        try config.ipsetMode.rawValue.write(to: EnginePaths.ipsetModeFile, atomically: true, encoding: .utf8)
        try (config.discordUdp ? "1" : "0").write(to: EnginePaths.discordUdpFile, atomically: true, encoding: .utf8)
        try (config.blockQuic ? "1" : "0").write(to: EnginePaths.blockQuicFile, atomically: true, encoding: .utf8)
        try (config.fastKeepinit ? "1" : "0").write(to: EnginePaths.fastKeepinitFile, atomically: true, encoding: .utf8)
        try gameFilterFileText(config).write(to: EnginePaths.gameFilterFile, atomically: true, encoding: .utf8)
    }

    static func readLists() -> [ListFile: String] {
        var result: [ListFile: String] = [:]
        for file in ListFile.allCases {
            let url = EnginePaths.listsDir.appendingPathComponent(file.rawValue)
            result[file] = (try? String(contentsOf: url, encoding: .utf8)) ?? file.defaultContent
        }
        return result
    }

    static func writeLists(_ lists: [ListFile: String]) throws {
        try ensureUserDataSeeded(defaultsFromPayload: false)
        for (file, content) in lists {
            let url = EnginePaths.listsDir.appendingPathComponent(file.rawValue)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func defaultLists() -> [ListFile: String] {
        var result: [ListFile: String] = [:]
        let roots: [URL] = [
            EngineBundle.stagingRoot.appendingPathComponent("default-lists"),
            Bundle.main.resourceURL,
        ].compactMap { $0 }
        for file in ListFile.allCases {
            var content = file.defaultContent
            for root in roots {
                let url = root.appendingPathComponent(file.rawValue)
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    content = text
                    break
                }
            }
            result[file] = content
        }
        return result
    }

    static func install(passwordless: Bool) throws -> CommandResult {
        let payload = try EngineBundle.materialize()
        try ensureUserDataSeeded()
        let script = """
        #!/bin/sh
        set -eu
        /bin/chmod -R u+rx "$1" || true
        /bin/chmod 755 "$1/install.sh" "$1/bin/utunws" 2>/dev/null || true
        exec "$1/install.sh" "$1" "$2" "$3"
        """
        return try PrivilegeRunner.runScript(
            script,
            args: [payload.path, EnginePaths.userDataRoot.path, passwordless ? "1" : "0"],
            timeoutSeconds: 300
        )
    }

    static func start() throws -> CommandResult {
        try writeRunningFilesIfNeeded()
        if canPasswordless() {
            let result = PrivilegeRunner.runPasswordless(EnginePaths.restartScript)
            if result.ok { return result }
        }
        return try PrivilegeRunner.runScriptFile(EnginePaths.restartScript)
    }

    static func stop() throws -> CommandResult {
        if canPasswordless() {
            let result = PrivilegeRunner.runPasswordless(EnginePaths.stopScript)
            if result.ok { return result }
        }
        return try PrivilegeRunner.runScriptFile(EnginePaths.stopScript)
    }

    static func restart() throws -> CommandResult {
        try start()
    }

    static func uninstall() throws -> CommandResult {
        guard FileManager.default.fileExists(atPath: EnginePaths.uninstallScript.path) else {
            throw EngineError.failed("uninstall.sh не найден — движок не установлен")
        }
        return try PrivilegeRunner.runScriptFile(EnginePaths.uninstallScript)
    }

    private static func canPasswordless() -> Bool {
        FileManager.default.fileExists(atPath: "/etc/sudoers.d/zapret")
            || FileManager.default.fileExists(atPath: "/etc/sudoers.d/zapret2")
    }

    private static func writeRunningFilesIfNeeded() throws {
        try ensureUserDataSeeded(defaultsFromPayload: false)
    }

    private static func primaryWanInterface() -> String? {
        let result = Shell.run(["/sbin/route", "-n", "get", "default"])
        guard result.ok else { return "en0" }
        for line in result.output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return "en0"
    }
}
