import SwiftUI

struct HomeView: View {
    @Environment(\.studioPalette) private var palette
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.top, 6)

            heroBoard

            if state.discordAppFound {
                GhostButton(title: state.discordUpdaterEnabled ? "Выключить апдейтер Discord" : "Включить апдейтер Discord") {
                    Task { await state.toggleDiscordUpdater() }
                }
            }

            PrerequisitesCard(prerequisites: state.prerequisites)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                InfoCard(
                    title: "Стратегия",
                    value: state.strategyTitle,
                    icon: "wand.and.stars",
                    tint: palette.peachDeep
                ) { state.show(.settings) }

                InfoCard(
                    title: "IP-список",
                    value: state.ipsetSummary,
                    icon: "point.3.connected.trianglepath.dotted",
                    tint: palette.sky
                ) { state.show(.settings) }

                InfoCard(
                    title: "Discord UDP",
                    value: state.config.discordUdp ? "включён" : "выкл",
                    icon: "waveform",
                    tint: palette.sage
                ) { state.show(.settings) }

                InfoCard(
                    title: "Сессия",
                    value: state.running ? state.uptimeText : "offline",
                    icon: "clock.fill",
                    tint: palette.lilac
                ) { state.show(.settings) }
            }
            .padding(.bottom, 4)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ZPRT")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(palette.ink)
                Text("Connection · developer by @pxdxz")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.inkSoft)
            }
            Spacer()
            HStack(spacing: 8) {
                ThemeToggleButton(isDark: state.isDarkTheme) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        state.toggleTheme()
                    }
                }
                Text(state.running ? "LIVE" : "IDLE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(state.running ? palette.accentOn : palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(state.running ? palette.sage : palette.paper.opacity(0.95))
                            .shadow(color: palette.shadow.opacity(0.5), radius: 8, y: 4)
                    )
            }
        }
    }

    private var heroBoard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("session")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.inkFaint)
                    Text(state.uptimeText)
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(palette.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("status")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.inkFaint)
                    Text(state.headline)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.peachDeep)
                }
            }

            PowerButtonView(
                running: state.running,
                busy: state.busy != nil,
                pulseToken: state.powerPulse,
                action: { Task { await state.togglePower() } }
            )

            Text(state.subline)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .softCard(padding: 20)
    }
}

struct PrerequisitesCard: View {
    @Environment(\.studioPalette) private var palette
    let prerequisites: Prerequisites

    var body: some View {
        if prerequisites.isReady {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("готовность")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.ink)

                check("Пакет двигателя", prerequisites.hasSources)
                check(
                    "Готовый бинарник",
                    prerequisites.hasPrebuiltBinary,
                    detail: prerequisites.hasPrebuiltBinary ? "в пакете" : "нужна пересборка"
                )
                check(
                    "WAN",
                    prerequisites.wanInterface != nil,
                    detail: prerequisites.wanInterface ?? "не найден"
                )
                check(
                    "Движок",
                    prerequisites.engineInstalled,
                    detail: prerequisites.engineInstalled ? "установлен" : "нажми GO"
                )
            }
            .softCard()
        }
    }

    private func check(_ label: String, _ ok: Bool, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ok ? palette.sage : palette.inkFaint)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.ink)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
