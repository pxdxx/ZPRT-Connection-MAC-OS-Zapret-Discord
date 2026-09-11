import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case home
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .settings: "Studio"
        }
    }

    var symbol: String {
        switch self {
        case .home: "sparkles"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum IpsetMode: String, CaseIterable, Identifiable {
    case none
    case loaded
    case any

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Выкл — только домены"
        case .loaded: "Пакетные IP (рекомендуется)"
        case .any: "Расширенный IP-режим"
        }
    }

    var hint: String {
        switch self {
        case .none:
            "Обход только по доменам из списков. IP-файлы не используются."
        case .loaded:
            "Берутся IP из пакетного ipset-all.txt (кладется при первой установке). Оптимально для Discord."
        case .any:
            "Более широкий охват по IP. Может дать лишнюю нагрузку."
        }
    }
}

struct StrategyEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
}

struct EngineConfig: Equatable {
    var strategyId: String
    var ipsetMode: IpsetMode
    var discordUdp: Bool
    var blockQuic: Bool

    /// Discord-first defaults out of the box.
    static let `default` = EngineConfig(
        strategyId: "general-simple-fake",
        ipsetMode: .loaded,
        discordUdp: true,
        blockQuic: true
    )
}

struct Prerequisites: Equatable {
    var hasSources: Bool
    var hasPrebuiltBinary: Bool
    var hasCompiler: Bool
    var wanInterface: String?
    var engineInstalled: Bool
    var passwordlessReady: Bool

    var isReady: Bool {
        hasSources
            && (hasPrebuiltBinary || hasCompiler)
            && wanInterface != nil
            && engineInstalled
    }

    static let demo = Prerequisites(
        hasSources: true,
        hasPrebuiltBinary: true,
        hasCompiler: true,
        wanInterface: "en0",
        engineInstalled: false,
        passwordlessReady: true
    )
}

struct ProbeResultRow: Identifiable, Equatable {
    let id: String
    let score: Int
    let stability: Int
    let latencyMs: Int?
    let discord: String
    let youtube: String
    let video: String
    let control: String
}

struct StrategyProbeReport: Equatable {
    var winnerId: String?
    var results: [ProbeResultRow]
}

struct Notice: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

enum ListFile: String, CaseIterable, Identifiable {
    case general = "list-general.txt"
    case generalUser = "list-general-user.txt"
    case google = "list-google.txt"
    case exclude = "list-exclude.txt"
    case excludeUser = "list-exclude-user.txt"
    case ipsetAll = "ipset-all.txt"
    case ipsetExclude = "ipset-exclude.txt"
    case ipsetExcludeUser = "ipset-exclude-user.txt"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "Домены (Discord и др.)"
        case .generalUser: "Домены пользователя"
        case .google: "Google / YouTube"
        case .exclude: "Исключения"
        case .excludeUser: "Исключения пользователя"
        case .ipsetAll: "IP-пакет (ipset-all)"
        case .ipsetExclude: "IP исключения"
        case .ipsetExcludeUser: "IP исключения пользователя"
        }
    }

    var defaultContent: String {
        switch self {
        case .generalUser:
            """
            # свои домены — по одному на строку
            """
        case .general:
            """
            discord.com
            discordapp.com
            discord.gg
            gateway.discord.gg
            cdn.discordapp.com
            media.discordapp.net
            images-ext-1.discordapp.net
            images-ext-2.discordapp.net
            """
        case .google:
            """
            youtube.com
            www.youtube.com
            googlevideo.com
            ytimg.com
            """
        default:
            ""
        }
    }
}

enum UninstallScope: String, CaseIterable, Identifiable {
    case appOnly
    case appAndEngine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appOnly: "Только приложение"
        case .appAndEngine: "Приложение и движок"
        }
    }
}

extension Array where Element == StrategyEntry {
    static let bundled: [StrategyEntry] = [
        .init(id: "general-simple-fake", title: "GENERAL (SIMPLE FAKE)", detail: "по умолчанию для Discord"),
        .init(id: "general-fake-tls-auto", title: "GENERAL (FAKE TLS AUTO)", detail: "если SIMPLE FAKE слабо"),
        .init(id: "general-pq-multisplit", title: "GENERAL (PQ MULTISPLIT)", detail: "жёсткий DPI"),
    ]
}
