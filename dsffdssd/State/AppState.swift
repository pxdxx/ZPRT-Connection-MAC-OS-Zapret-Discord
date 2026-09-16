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
    var autoUpdate = true
    var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    var updateAvailable: String?
    var probePhase: String?
    var probeReport: StrategyProbeReport?

    var prerequisites = Prerequisites.demo
    var strategies: [StrategyEntry] = .bundled
    var listContents: [ListFile: String] = Dictionary(uniqueKeysWithValues: ListFile.allCases.map { ($0, $0.defaultContent) })
    var defaultListContents: [ListFile: String] = Dictionary(uniqueKeysWithValues: ListFile.allCases.map { ($0, $0.defaultContent) })
    var listsRevision: Int = 0
    var isDarkTheme: Bool = UserDefaults.standard.bool(forKey: "zprt.isDarkTheme")
    var ipsetEntryCount: Int = 0

    private var tickTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

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
            return "\(config.strategyId) · \(config.ipsetMode.rawValue) · Discord UDP \(config.discordUdp ? "on" : "off")"
        }
        return "Нажмите GO, чтобы включить обход Discord"
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
            notifyTray()
            return
        }
        didBootstrap = true
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

    func setAutoUpdate(_ value: Bool) { autoUpdate = value }

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

    func probeStrategies() async {
        guard busy == nil, probePhase == nil else { return }
        guard installed else {
            pushNotice("Сначала установите движок", error: true)
            return
        }
        probePhase = "Старт…"
        let list = strategies
        probeReport = await EngineService.probeStrategies(strategies: list) { phase in
            self.probePhase = phase
        }
        probePhase = nil
        if let winner = probeReport?.winnerId {
            pushNotice("Лучшая стратегия: \(winner)")
        } else {
            pushNotice("Подходящая стратегия не найдена", error: true)
        }
    }

    func checkForUpdates() async {
        pushNotice("Версия \(appVersion)")
    }

    func updateNow() async {
        pushNotice("Обновления — через новый билд ZPRT Connection")
    }

    func launchDiscordBypassingUpdater() async {
        let bundleId = "com.hnc.Discord"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if !running.isEmpty {
            for app in running { app.terminate() }
            for _ in 0..<25 {
                try? await Task.sleep(for: .milliseconds(200))
                if NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty { break }
            }
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            pushNotice("Discord.app не найден", error: true)
            return
        }
        let binary = appURL.appendingPathComponent("Contents/MacOS/Discord")
        let task = Process()
        task.executableURL = binary
        task.arguments = ["--disable-updater"]
        do {
            try task.run()
            pushNotice("Discord перезапущен без апдейтера")
        } catch {
            pushNotice("Не удалось перезапустить Discord: \(error.localizedDescription)", error: true)
        }
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
