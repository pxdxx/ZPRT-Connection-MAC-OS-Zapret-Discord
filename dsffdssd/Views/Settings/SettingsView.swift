import SwiftUI

struct SettingsView: View {
    @Environment(\.studioPalette) private var palette
    @Bindable var state: AppState

    @State private var draft = EngineConfig.default
    @State private var lists: [ListFile: String] = [:]
    @State private var selectedList: ListFile = .general
    @State private var systemAdvanced = false
    @State private var askUninstall = false
    @State private var editorToken = UUID()
    @State private var showPlatformPicker = false

    private var editable: Bool {
        state.busy == nil && state.probePhase == nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                actionCard
                antiDpiSection
                listsSection
                systemSection
            }
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: syncFromState)
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
                enabled: editable
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
            description: "По умолчанию уже заточено под Discord. VPN — только split-tunnel.",
            credit: "discord",
            accent: palette.peachDeep
        ) {
            strategyPicker

            GhostButton(
                title: state.probePhase ?? "Подобрать стратегию",
                enabled: editable && state.installed
            ) {
                Task { await state.probeStrategies() }
            }

            if let report = state.probeReport {
                probeSummary(report)
            }

            Text("IP-список")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.inkFaint)

            Text("При первой установке пакетный ipset-all.txt копируется автоматически. Сейчас: \(state.ipsetEntryCount) записей.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.inkSoft)

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
        }
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

    private var listsSection: some View {
        SettingsSection(
            title: "Списки",
            description: "Discord уже в «Домены (Discord и др.)». Свои сайты — в «Домены пользователя».",
            accent: palette.sky
        ) {
            Picker("Файл", selection: $selectedList) {
                ForEach(ListFile.allCases) { file in
                    Text(file.label).tag(file)
                }
            }
            .pickerStyle(.menu)
            .disabled(!editable)
            .onChange(of: selectedList) { _, _ in
                editorToken = UUID()
            }

            LabeledField(
                label: selectedList.label,
                text: binding(for: selectedList),
                mono: true,
                minHeight: 140,
                enabled: editable
            )
            .id("\(selectedList.rawValue)-\(editorToken.uuidString)-\(state.listsRevision)")

            Text("Один хост на строку, без https://. После правок — «Применить».")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.inkSoft)

            HStack(spacing: 16) {
                TextActionButton(title: "Сбросить выбранный", enabled: editable) {
                    state.resetList(selectedList)
                    syncFromState()
                }
                TextActionButton(title: "Сбросить все к пакету", enabled: editable) {
                    state.resetAllLists()
                    syncFromState()
                }
            }

            GhostButton(title: "Добавить платформу", enabled: editable) {
                showPlatformPicker = true
            }
        }
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerSheet(alreadyAdded: platformAlreadyAdded, onAdd: addPlatform)
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
                SwitchRow(
                    label: "Автообновление",
                    isOn: Binding(
                        get: { state.autoUpdate },
                        set: { state.setAutoUpdate($0) }
                    ),
                    enabled: editable
                )
                GhostButton(title: "Проверить обновления", enabled: editable) {
                    Task { await state.checkForUpdates() }
                }
            }

            TextActionButton(title: "Удалить…", danger: true, enabled: editable) {
                askUninstall = true
            }
        }
    }

    private func probeSummary(_ report: StrategyProbeReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.winnerId.map { "Лучшая: \($0)" } ?? "Подходящая стратегия не найдена")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(report.winnerId == nil ? palette.danger : palette.sage)

            ForEach(report.results) { row in
                Text("\(row.id): \(row.score) · \(row.stability)% · \(row.latencyMs.map { "\($0)ms" } ?? "—")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.inkSoft)
            }

            if let winner = report.winnerId {
                TextActionButton(title: "Применить \(winner)", enabled: editable) {
                    draft.strategyId = winner
                }
            }
        }
        .padding(.top, 4)
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

    /// Appends to the user list — never clears it, only adds domains that aren't already there.
    private func addPlatform(_ platform: PopularPlatform) {
        let existing = userDomainSet()
        let newDomains = platform.domains.filter { !existing.contains($0.lowercased()) }
        guard !newDomains.isEmpty else { return }

        var current = lists[.generalUser] ?? ""
        if !current.isEmpty && !current.hasSuffix("\n") { current += "\n" }
        current += "# \(platform.name)\n" + newDomains.joined(separator: "\n") + "\n"
        lists[.generalUser] = current
        selectedList = .generalUser
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
