import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class AppState {
    var screen: AppScreen = .home
    var installed = false
    var running = false
    var busy: String?
    var notice: Notice?
    var startedAt: Date?
    var now = Date()
    var powerPulse = 0

    var config = EngineConfig.default
    var passwordless = true
    var autoUpdate: Bool = UserDefaults.standard.object(forKey: "zprt.autoUpdate") as? Bool ?? true
    var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    var availableRelease: GitHubRelease?
    var checkingForUpdate = false

    var prerequisites = Prerequisites.demo
    var strategies: [StrategyEntry] = .bundled
    var listContents: [ListFile: String] = Dictionary(uniqueKeysWithValues: ListFile.allCases.map { ($0, $0.defaultContent) })
    var defaultListContents: [ListFile: String] = Dictionary(uniqueKeysWithValues: ListFile.allCases.map { ($0, $0.defaultContent) })
    var listsRevision: Int = 0
    var isDarkTheme: Bool = UserDefaults.standard.bool(forKey: "zprt.isDarkTheme")
    var ipsetEntryCount: Int = 0
    var discordAppFound = false
    var dns: DNSState?
    var dnsBusy = false
    var discordUpdaterEnabled = true

    private var tickTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var updateCheckTask: Task<Void, Never>?

    var uptimeText: String {
        guard running, let startedAt else { return "--:--:--" }
        let total = max(0, Int(now.timeIntervalSince(startedAt)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var headline: String {
        if let busy { return busy }
        if !installed { return "Не установлен" }
        if running { return "Работает" }
        return "Остановлено"
    }

    var subline: String {
        if !installed { return "Нажмите GO — установка под Discord одним шагом" }
        if running {
            let games = config.gameFilter.isEnabled && config.ipsetMode != .none ? " · игры \(config.gameFilter.label)" : ""
            return "\(config.strategyId) · \(config.ipsetMode.rawValue) · Discord UDP \(config.discordUdp ? "on" : "off")\(games)"
        }
        return "Нажмите GO, чтобы включить обход"
    }

    var strategyTitle: String {
        strategies.first { $0.id == config.strategyId }?.title ?? config.strategyId
    }

    var ipsetSummary: String {
        switch config.ipsetMode {
        case .none: "выкл"
        case .loaded: ipsetEntryCount > 0 ? "пакет · \(ipsetEntryCount)" : "пакет"
        case .any: "расширенный"
        }
    }

    init() {
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                now = Date()
            }
        }
    }

    private var didBootstrap = false

    func bootstrap() {
        guard !didBootstrap else {
            refreshStatus()
            refreshDiscordUpdaterState()
            notifyTray()
            return
        }
        didBootstrap = true
        refreshDiscordUpdaterState()
        strategies = EngineService.loadStrategies()
        defaultListContents = EngineService.defaultLists()
        // Seed lists only if missing — never overwrite saved strategy/config on relaunch.
        try? EngineService.ensureUserDataSeeded()
        config = EngineService.readConfig()
        if config.strategyId.isEmpty {
            config = .default
            try? EngineService.writeConfig(config)
        }
        listContents = EngineService.readLists()
        refreshIpsetCount()
        passwordless = UserDefaults.standard.object(forKey: "zprt.passwordless") as? Bool ?? true
        refreshStatus()
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                refreshStatus()
            }
        }
        updateCheckTask?.cancel()
        updateCheckTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                if let self, self.autoUpdate { await self.checkForUpdates() }
                try? await Task.sleep(for: .seconds(3600))
            }
        }
        notifyTray()
    }

    func show(_ screen: AppScreen) { self.screen = screen }

    func toggleTheme() {
        withThemeAnimation {
            isDarkTheme.toggle()
        }
        UserDefaults.standard.set(isDarkTheme, forKey: "zprt.isDarkTheme")
    }

    func dismissNotice() { notice = nil }

    private var statusRefreshInFlight = false

    /// Prerequisites/installed/running all shell out to ifconfig/launchctl/route.
    /// Those can block for a while (especially launchctl right after install/stop),
    /// so never run them on the main actor — that used to freeze the whole UI
    /// (including the uptime timer) every 3s via the poll loop.
    func refreshStatus() {
        guard !statusRefreshInFlight else { return }
        statusRefreshInFlight = true
        Task.detached { [weak self] in
            let prerequisites = EngineService.refreshPrerequisites()
            let installed = EnginePaths.isInstalled
            let running = installed && EnginePaths.isRunning
            await MainActor.run {
                guard let self else { return }
                self.statusRefreshInFlight = false
                self.prerequisites = prerequisites
                self.installed = installed
                let wasRunning = self.running
                self.running = running
                if self.running, self.startedAt == nil { self.startedAt = Date() }
                if !self.running { self.startedAt = nil }
                if wasRunning != self.running { self.notifyTray() }
                self.refreshIpsetCount()
            }
        }
    }

    func refreshIpsetCount() {
        let text = listContents[.ipsetAll] ?? defaultListContents[.ipsetAll] ?? ""
        ipsetEntryCount = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .count
    }

    func togglePower() async {
        guard busy == nil else { return }
        if !installed {
            await installEngine()
            return
        }
        if running {
            busy = "Остановка…"
            notifyTray()
            let result = await Task.detached { try? EngineService.stop() }.value
            busy = nil
            if let result, result.ok {
                running = false
                startedAt = nil
                pushNotice("Обход выключен")
            } else {
                pushNotice(result?.lastLine ?? "Не удалось остановить", error: true)
            }
        } else {
            busy = "Запуск…"
            notifyTray()
            let cfg = config
            let lists = listContents
            let result = await Task.detached {
                do {
                    try EngineService.writeConfig(cfg)
                    try EngineService.writeLists(lists)
                    return try EngineService.start()
                } catch {
                    return CommandResult(ok: false, output: error.localizedDescription)
                }
            }.value
            busy = nil
            if result.ok {
                running = true
                startedAt = Date()
                powerPulse += 1
                pushNotice("Обход Discord включён")
            } else {
                pushNotice(result.lastLine.isEmpty ? result.output : result.lastLine, error: true)
            }
        }
        refreshStatus()
        notifyTray()
    }

    func setPasswordless(_ value: Bool) {
        passwordless = value
        UserDefaults.standard.set(value, forKey: "zprt.passwordless")
        pushNotice(value ? "Вкл/выкл без пароля при следующей установке" : "Потребуется пароль администратора")
    }

    func setAutoUpdate(_ value: Bool) {
        autoUpdate = value
        UserDefaults.standard.set(value, forKey: "zprt.autoUpdate")
    }

    func applyConfig(_ draft: EngineConfig, lists: [ListFile: String]) async {
        guard busy == nil else { return }
        busy = installed ? "Применение…" : "Сохранение…"
        notifyTray()
        let shouldRestart = installed && running
        let result = await Task.detached {
            do {
                try EngineService.writeConfig(draft)
                try EngineService.writeLists(lists)
                if shouldRestart {
                    return try EngineService.restart()
                }
                return CommandResult(ok: true, output: "saved")
            } catch {
                return CommandResult(ok: false, output: error.localizedDescription)
            }
        }.value
        busy = nil
        if result.ok {
            config = draft
            listContents = lists
            listsRevision += 1
            refreshIpsetCount()
            if shouldRestart { startedAt = Date() }
            pushNotice("Настройки сохранены")
        } else {
            pushNotice(result.lastLine.isEmpty ? result.output : result.lastLine, error: true)
        }
        refreshStatus()
        notifyTray()
    }

    func installEngine() async {
        guard busy == nil else { return }
        busy = "Установка…"
        notifyTray()
        // Force Discord-first config before install
        config = .default
        let nopass = passwordless
        let cfg = config
        let lists = listContents
        let result = await Task.detached {
            do {
                try EngineService.writeConfig(cfg)
                try EngineService.writeLists(lists)
                return try EngineService.install(passwordless: nopass)
            } catch let error as EngineError {
                return CommandResult(ok: false, output: error.errorDescription ?? "error")
            } catch {
                return CommandResult(ok: false, output: error.localizedDescription)
            }
        }.value
        busy = nil
        if result.ok {
            installed = true
            running = true
            startedAt = Date()
            prerequisites.engineInstalled = true
            powerPulse += 1
            pushNotice("Готово: Discord-профиль установлен")
        } else {
            let message = result.lastLine.isEmpty ? result.output : result.lastLine
            pushNotice(message.isEmpty ? "Установка отменена или не удалась" : message, error: true)
        }
        refreshStatus()
        notifyTray()
    }

    func uninstall(_ scope: UninstallScope) async {
        guard busy == nil else { return }
        busy = "Удаление…"
        notifyTray()
        if scope == .appAndEngine {
            let result = await Task.detached {
                do { return try EngineService.uninstall() }
                catch { return CommandResult(ok: false, output: error.localizedDescription) }
            }.value
            if result.ok {
                installed = false
                prerequisites.engineInstalled = false
                pushNotice("Движок удалён")
            } else {
                pushNotice(result.lastLine.isEmpty ? result.output : result.lastLine, error: true)
                busy = nil
                notifyTray()
                return
            }
        } else {
            pushNotice("Выйдите через трей → Закрыть полностью")
        }
        running = false
        startedAt = nil
        screen = .home
        busy = nil
        refreshStatus()
        notifyTray()
    }

    func checkForUpdates() async {
        guard !checkingForUpdate else { return }
        checkingForUpdate = true
        let version = appVersion
        let release = await Task.detached { await Updater.checkLatestRelease(currentVersion: version) }.value
        checkingForUpdate = false
        if let release {
            availableRelease = release
            pushNotice("Доступна версия \(Updater.displayVersion(release.tagName))")
        } else {
            availableRelease = nil
            pushNotice("Установлена последняя версия (\(appVersion))")
        }
    }

    func openLatestReleasePage() {
        NSWorkspace.shared.open(availableRelease?.htmlURL ?? Updater.releasesPageURL)
    }

    /// Discord's own updater can't run if it can't overwrite its own app
    /// bundle, so we (un)lock write access on Discord.app itself — a
    /// persistent toggle, unlike relaunching once with --disable-updater.
    func refreshDiscordUpdaterState() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.hnc.Discord") else {
            discordAppFound = false
            return
        }
        discordAppFound = true
        discordUpdaterEnabled = FileManager.default.isWritableFile(atPath: appURL.path)
    }

    func toggleDiscordUpdater() async {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.hnc.Discord") else {
            pushNotice("Discord.app не найден", error: true)
            return
        }
        let enable = !discordUpdaterEnabled
        let path = appURL.path
        let result = await Task.detached {
            Shell.run(["/bin/chmod", "-R", enable ? "u+w" : "a-w", path], timeoutSeconds: 30)
        }.value
        if result.ok {
            discordUpdaterEnabled = enable
            pushNotice(enable ? "Апдейтер Discord включён" : "Апдейтер Discord выключен")
        } else {
            pushNotice("Не удалось изменить права доступа Discord.app", error: true)
        }
    }

    func diagnosticsText() -> String {
        var lines: [String] = [
            "ZPRT Connection \(appVersion)",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Установлен: \(installed ? "да" : "нет") · Работает: \(running ? "да" : "нет")",
            "Стратегия: \(config.strategyId) · IP-режим: \(config.ipsetMode.rawValue) · Game Filter: \(config.gameFilter.rawValue)",
            "WAN: \(prerequisites.wanInterface ?? "—")",
        ]
        let logURL = URL(fileURLWithPath: "/Library/Application Support/Zapret/engine.log")
        if let log = try? String(contentsOf: logURL, encoding: .utf8) {
            let tail = log.split(whereSeparator: \.isNewline).suffix(30)
            if !tail.isEmpty {
                lines.append("")
                lines.append("--- engine.log (последние строки) ---")
                lines.append(contentsOf: tail.map(String.init))
            }
        }
        return lines.joined(separator: "\n")
    }

    func refreshDNS() async {
        dns = await Task.detached { DNSService.read() }.value
    }

    func setDNS(_ choice: DNSChoice) async {
        guard !dnsBusy, let current = dns, current.choice != choice else { return }
        dnsBusy = true
        let service = current.service
        do {
            let result = try await Task.detached { try DNSService.apply(choice, service: service) }.value
            if result.ok {
                pushNotice(choice == .system ? "DNS сброшен на автоматический" : "DNS: \(choice.title)")
            } else {
                pushNotice(result.lastLine.isEmpty ? "Не удалось сменить DNS" : result.lastLine, error: true)
            }
        } catch {
            pushNotice(error.localizedDescription, error: true)
        }
        await refreshDNS()
        dnsBusy = false
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pushNotice("Скопировано в буфер обмена")
    }

    func resetList(_ file: ListFile) {
        listContents[file] = defaultListContents[file]
        listsRevision += 1
        refreshIpsetCount()
    }

    func resetAllLists() {
        listContents = defaultListContents
        listsRevision += 1
        refreshIpsetCount()
        pushNotice("Списки сброшены к пакету Discord")
    }

    private func withThemeAnimation(_ body: () -> Void) {
        body()
    }

    private func pushNotice(_ text: String, error: Bool = false) {
        notice = Notice(text: text, isError: error)
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if notice?.text == text { notice = nil }
        }
    }

    private func notifyTray() {
        NotificationCenter.default.post(name: .outpostTrayNeedsRefresh, object: nil)
    }
}
