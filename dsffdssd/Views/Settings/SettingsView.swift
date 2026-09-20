import SwiftUI

struct SettingsView: View {
    @Environment(\.studioPalette) private var palette
    @Bindable var state: AppState

    @State private var draft = EngineConfig.default
    @State private var lists: [ListFile: String] = [:]
    @State private var systemAdvanced = false
    @State private var askUninstall = false
    @State private var editorToken = UUID()
    @State private var showPlatformPicker = false
    @State private var showDiagnostics = false

    private var editable: Bool {
        state.busy == nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                actionCard
                antiDpiSection
                dnsSection
                listsSection
                systemSection
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: syncFromState)
        .task { await state.refreshDNS() }
        .onChange(of: state.config) { _, _ in syncFromState() }
        .onChange(of: state.listsRevision) { _, _ in syncFromState() }
        .onChange(of: state.listContents) { _, _ in syncFromState() }
        .confirmationDialog("Удалить ZPRT Connection?", isPresented: $askUninstall, titleVisibility: .visible) {
            Button(UninstallScope.appOnly.title) {
                Task { await state.uninstall(.appOnly) }
            }
            Button(UninstallScope.appAndEngine.title, role: .destructive) {
                Task { await state.uninstall(.appAndEngine) }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Движок удаляется из /Library/Application Support/Zapret.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("studio")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.ink)
            Text("discord · стратегии · списки · система")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.inkSoft)
        }
        .padding(.top, 4)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("действия")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.inkFaint)

            AccentButton(
                title: state.installed ? "Применить и перезапустить" : "Сохранить настройки",
                enabled: editable && draft.gamePortsValid
            ) {
                Task {
                    await state.applyConfig(draft, lists: lists)
                    syncFromState()
                }
            }

            if !state.installed {
                GhostButton(title: "Установить движок", enabled: editable) {
                    Task { await state.installEngine() }
                }
            }
        }
        .softCard()
    }

    private var antiDpiSection: some View {
        SettingsSection(
            title: "Анти-DPI",
            credit: "discord",
            accent: palette.peachDeep
        ) {
            strategyPicker

            Text("IP-список")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.inkFaint)

            ForEach(IpsetMode.allCases) { mode in
                VStack(alignment: .leading, spacing: 4) {
                    ChoiceRow(label: mode.label, selected: draft.ipsetMode == mode) {
                        draft.ipsetMode = mode
                    }
                    if draft.ipsetMode == mode {
                        Text(mode.hint)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.inkSoft)
                            .padding(.leading, 4)
                    }
                }
            }

            gameFilterBlock

            SwitchRow(
                label: "Discord UDP порты",
                description: "Голос Discord через PF",
                isOn: $draft.discordUdp,
                enabled: editable
            )

            SwitchRow(
                label: "Блокировать QUIC (HTTP/3)",
                description: "Полезно для YouTube в браузере",
                isOn: $draft.blockQuic,
                enabled: editable
            )

            SwitchRow(
                label: "Быстрый отказ от заблокированных IP",
                description: "Снижает системный TCP keepinit до 7с на время работы обхода, чтобы зависшие соединения быстрее срывались на повтор",
                isOn: $draft.fastKeepinit,
                enabled: editable
            )
        }
    }

    private var gameFilterBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ИГРОВОЙ ФИЛЬТР")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.inkFaint)

            ForEach(GameFilterMode.allCases) { mode in
                ChoiceRow(label: mode.label, selected: draft.gameFilter == mode) {
                    draft.gameFilter = mode
                }
            }

            if draft.gameFilter.isEnabled {
                Text("Обход на портах игр, только для IP из списка (при IP-списке «Выкл» не действует). Нагружает сеть; если игра перестала грузиться - выключите фильтр.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.inkSoft)
                    .padding(.leading, 4)
            }

            if draft.gameFilter.usesTcp {
                LabeledField(label: "TCP порты", text: $draft.gameTcpPorts, mono: true, enabled: editable)
                if !GameFilterMode.isValidPorts(draft.gameTcpPorts) { portsError }
            }
            if draft.gameFilter.usesUdp {
                LabeledField(label: "UDP порты", text: $draft.gameUdpPorts, mono: true, enabled: editable)
                if !GameFilterMode.isValidPorts(draft.gameUdpPorts) { portsError }
            }
        }
    }

    private var portsError: some View {
        Text("Порты через запятую или диапазоны, 1-65535: 80,443,27000-27050")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.red)
            .padding(.leading, 4)
    }

    private var strategyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("СТРАТЕГИЯ")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(palette.inkFaint)

            Picker("Стратегия", selection: $draft.strategyId) {
                ForEach(state.strategies) { strategy in
                    Text(strategy.title).tag(strategy.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(!editable)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OutpostDimens.radiusField, style: .continuous)
                    .fill(palette.field)
            )

            if let detail = state.strategies.first(where: { $0.id == draft.strategyId })?.detail {
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.inkSoft)
            }
        }
    }

    private var dnsSection: some View {
        SettingsSection(title: "DNS", accent: palette.sky) {
            ForEach(DNSChoice.allCases) { choice in
                ChoiceRow(
                    label: choice.title,
                    selected: state.dns?.choice == choice,
                    enabled: state.dns != nil && !state.dnsBusy
                ) {
                    Task { await state.setDNS(choice) }
                }
            }

            Text(dnsStatus)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.inkSoft)
        }
    }

    private var dnsStatus: String {
        if state.dnsBusy { return "Применяется…" }
        guard let dns = state.dns else { return "Активная сеть не найдена" }
        let servers = dns.servers.isEmpty ? "автоматически" : dns.servers.joined(separator: ", ")
        return "\(dns.service): \(servers)" + (dns.choice == nil ? " (свой)" : "")
    }

    private var listsSection: some View {
        SettingsSection(
            title: "Списки",
            accent: palette.sky
        ) {
            LabeledField(
                label: "Домены (Discord и добавленные платформы)",
                text: binding(for: .generalUser),
                mono: true,
                minHeight: 140,
                enabled: editable
            )
            .id("\(editorToken.uuidString)-\(state.listsRevision)")

            HStack(spacing: 16) {
                TextActionButton(title: "Сбросить домены", enabled: editable) {
                    state.resetList(.generalUser)
                    syncFromState()
                }
                TextActionButton(title: "Сбросить всё к пакету", enabled: editable) {
                    state.resetAllLists()
                    syncFromState()
                }
            }

            GhostButton(title: "Добавить платформу", enabled: editable) {
                showPlatformPicker = true
            }
        }
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerSheet(isDarkTheme: state.isDarkTheme, alreadyAdded: platformAlreadyAdded, onToggle: togglePlatform)
        }
    }

    private var systemSection: some View {
        SettingsSection(title: "Система", accent: palette.inkSoft) {
            SwitchRow(
                label: "Вкл/выкл без пароля",
                description: "После установки стоп/старт без sudo.",
                isOn: Binding(
                    get: { state.passwordless },
                    set: { state.setPasswordless($0) }
                ),
                enabled: editable
            )

            TextActionButton(
                title: systemAdvanced ? "Скрыть обновления" : "Обновления · v\(state.appVersion)",
                enabled: true
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { systemAdvanced.toggle() }
            }

            if systemAdvanced {
                updatesCard
            }

            GhostButton(title: "Диагностика", enabled: true) {
                showDiagnostics = true
            }
            .sheet(isPresented: $showDiagnostics) {
                DiagnosticsSheet(isDarkTheme: state.isDarkTheme, text: state.diagnosticsText(), onCopy: state.copyToClipboard)
            }

            TextActionButton(title: "Удалить…", danger: true, enabled: editable) {
                askUninstall = true
            }
        }
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SwitchRow(
                label: "Автообновление",
                description: "Тихая проверка раз в час, открывает страницу релиза на GitHub",
                isOn: Binding(
                    get: { state.autoUpdate },
                    set: { state.setAutoUpdate($0) }
                ),
                enabled: editable
            )

            GhostButton(
                title: state.checkingForUpdate ? "Проверка…" : "Проверить обновления",
                enabled: editable && !state.checkingForUpdate
            ) {
                Task { await state.checkForUpdates() }
            }

            if let release = state.availableRelease {
                Text("Доступна версия \(Updater.displayVersion(release.tagName))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.sage)
            }
        }
    }

    private func userDomainSet() -> Set<String> {
        Set(
            (lists[.generalUser] ?? "")
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        )
    }

    private func platformAlreadyAdded(_ platform: PopularPlatform) -> Bool {
        let existing = userDomainSet()
        return platform.domains.allSatisfy { existing.contains($0.lowercased()) }
    }

    private func togglePlatform(_ platform: PopularPlatform) {
        if platformAlreadyAdded(platform) {
            removePlatform(platform)
        } else {
            addPlatform(platform)
        }
    }

    /// Appends to the domains list — never clears it, only adds domains that aren't already there.
    private func addPlatform(_ platform: PopularPlatform) {
        let existing = userDomainSet()
        let newDomains = platform.domains.filter { !existing.contains($0.lowercased()) }
        guard !newDomains.isEmpty else { return }

        var current = lists[.generalUser] ?? ""
        if !current.isEmpty && !current.hasSuffix("\n") { current += "\n" }
        current += "# \(platform.name)\n" + newDomains.joined(separator: "\n") + "\n"
        lists[.generalUser] = current
        editorToken = UUID()
    }

    /// Removes exactly the domains (and header comment) that this platform would have added.
    private func removePlatform(_ platform: PopularPlatform) {
        let domainsLower = Set(platform.domains.map { $0.lowercased() })
        let header = "# \(platform.name)"
        let current = lists[.generalUser] ?? ""
        let kept = current
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == header { return false }
                if domainsLower.contains(trimmed.lowercased()) { return false }
                return true
            }
        lists[.generalUser] = kept.joined(separator: "\n")
        editorToken = UUID()
    }

    private func binding(for file: ListFile) -> Binding<String> {
        Binding(
            get: { lists[file] ?? "" },
            set: { lists[file] = $0 }
        )
    }

    private func syncFromState() {
        draft = state.config
        lists = state.listContents
        editorToken = UUID()
    }
}
