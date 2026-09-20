import Foundation

// Plain Sendable data types — read from both @MainActor UI code and the
// nonisolated Engine* background layer, so none of these should pick up the
// project's default @MainActor isolation.

nonisolated enum AppScreen: String, CaseIterable, Identifiable {
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

nonisolated enum IpsetMode: String, CaseIterable, Identifiable {
    case none
    case loaded
    case any

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Выкл - только домены (empty)"
        case .loaded: "Пакетные IP (рекомендуется)"
        case .any: "Расширенный IP-режим"
        }
    }

    var hint: String {
        switch self {
        case .none:
            "Обход только по доменам из списков, IP-список не используется (и игровой фильтр тоже). Включите, если игра или сервис, которые работают без обхода, перестали грузиться."
        case .loaded:
            "Берутся IP из пакетного ipset-all.txt (кладется при первой установке). Оптимально для Discord."
        case .any:
            "Более широкий охват по IP. Может дать лишнюю нагрузку."
        }
    }
}

/// Flowseal "Game Filter": also runs the bypass on high TCP/UDP ports, but only for
/// IPs from the ipset. Off by default because it breaks some games (Dota, etc.).
nonisolated enum GameFilterMode: String, CaseIterable, Identifiable {
    case disabled
    case all
    case tcp
    case udp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .disabled: "Выкл"
        case .all: "TCP и UDP"
        case .tcp: "Только TCP"
        case .udp: "Только UDP"
        }
    }

    var isEnabled: Bool { self != .disabled }
    var usesTcp: Bool { self == .all || self == .tcp }
    var usesUdp: Bool { self == .all || self == .udp }

    static let defaultPorts = "1024-65535"

    /// Same rules as run.sh: comma-separated ports or ranges, 1...65535, ascending.
    static func isValidPorts(_ text: String) -> Bool {
        let trimmed = text.filter { !$0.isWhitespace }
        guard !trimmed.isEmpty, trimmed.count <= 120 else { return false }
        for part in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            let bounds = part.split(separator: "-", omittingEmptySubsequences: false)
            guard bounds.count <= 2,
                  let low = Int(bounds[0]), let high = Int(bounds.last!),
                  bounds.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
                  (1...65535).contains(low), (1...65535).contains(high), low <= high
            else { return false }
        }
        return true
    }
}

nonisolated struct StrategyEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
}

nonisolated struct EngineConfig: Equatable {
    var strategyId: String
    var ipsetMode: IpsetMode
    var discordUdp: Bool
    var blockQuic: Bool
    var fastKeepinit: Bool
    var gameFilter: GameFilterMode = .disabled
    var gameTcpPorts: String = GameFilterMode.defaultPorts
    var gameUdpPorts: String = GameFilterMode.defaultPorts

    var gamePortsValid: Bool {
        (!gameFilter.usesTcp || GameFilterMode.isValidPorts(gameTcpPorts))
            && (!gameFilter.usesUdp || GameFilterMode.isValidPorts(gameUdpPorts))
    }

    /// Discord-first defaults out of the box.
    static let `default` = EngineConfig(
        strategyId: "general-simple-fake",
        ipsetMode: .loaded,
        discordUdp: true,
        blockQuic: true,
        fastKeepinit: true
    )
}

nonisolated struct Prerequisites: Equatable {
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

nonisolated struct Notice: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

nonisolated enum ListFile: String, CaseIterable, Identifiable {
    case general = "list-general.txt"
    case generalUser = "list-general-user.txt"
    case google = "list-google.txt"
    case exclude = "list-exclude.txt"
    case excludeUser = "list-exclude-user.txt"
    case ipsetAll = "ipset-all.txt"
    case ipsetExclude = "ipset-exclude.txt"
    case ipsetExcludeUser = "ipset-exclude-user.txt"

    var id: String { rawValue }

    /// The three "-user" files are the only ones with any UI to edit them —
    /// everything else is a package list with no supported way to customize
    /// it, so it's always safe (and necessary for fixes to reach existing
    /// installs) to keep those in sync with the currently bundled defaults.
    var isUserManaged: Bool { rawValue.contains("-user.") }

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
            # Свои домены можно дописывать ниже, по одному на строку.
            dis.gd
            discord-attachments-uploads-prd.storage.googleapis.com
            discord.app
            discord.co
            discord.com
            discord.design
            discord.dev
            discord.gift
            discord.gifts
            discord.gg
            discord.media
            discord.new
            discord.store
            discord.status
            discord-activities.com
            discordactivities.com
            discordapp.com
            discordapp.net
            discordcdn.com
            discordmerch.com
            discordpartygames.com
            discordsays.com
            discordsez.com
            discordstatus.com
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

nonisolated struct PopularPlatform: Identifiable, Hashable {
    let id: String
    let name: String
    /// Name of the vector image set in Assets.xcassets (official brand mark).
    let assetName: String
    let tintHex: UInt32
    let domains: [String]
}

nonisolated extension Array where Element == PopularPlatform {
    /// Часто блокируемые/замедляемые платформы. Discord уже покрыт списком general по умолчанию.
    static let popularPlatforms: [PopularPlatform] = [
        .init(
            id: "youtube", name: "YouTube", assetName: "platform-youtube", tintHex: 0xFF0000,
            domains: [
                "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
                "youtube-nocookie.com", "ytimg.com", "googlevideo.com",
                "yt3.ggpht.com", "youtubei.googleapis.com",
            ]
        ),
        .init(
            id: "instagram", name: "Instagram", assetName: "platform-instagram", tintHex: 0xE4405F,
            domains: ["instagram.com", "www.instagram.com", "cdninstagram.com", "scontent.cdninstagram.com", "instagr.am"]
        ),
        .init(
            id: "facebook", name: "Facebook", assetName: "platform-facebook", tintHex: 0x1877F2,
            domains: ["facebook.com", "www.facebook.com", "fbcdn.net", "facebook.net", "fb.com", "fbsbx.com", "messenger.com"]
        ),
        .init(
            id: "twitter", name: "X (Twitter)", assetName: "platform-x", tintHex: 0x000000,
            domains: ["twitter.com", "x.com", "twimg.com", "t.co"]
        ),
        .init(
            id: "linkedin", name: "LinkedIn", assetName: "platform-linkedin", tintHex: 0x0A66C2,
            domains: ["linkedin.com", "www.linkedin.com", "licdn.com"]
        ),
        .init(
            id: "pinterest", name: "Pinterest", assetName: "platform-pinterest", tintHex: 0xE60023,
            domains: ["pinterest.com", "www.pinterest.com", "pinimg.com"]
        ),
        .init(
            id: "twitch", name: "Twitch", assetName: "platform-twitch", tintHex: 0x9146FF,
            domains: ["twitch.tv", "www.twitch.tv", "ttvnw.net", "jtvnw.net"]
        ),
        .init(
            id: "spotify", name: "Spotify", assetName: "platform-spotify", tintHex: 0x1DB954,
            domains: ["spotify.com", "www.spotify.com", "scdn.co", "spotifycdn.com"]
        ),
        .init(
            id: "whatsapp", name: "WhatsApp", assetName: "platform-whatsapp", tintHex: 0x25D366,
            domains: ["whatsapp.com", "www.whatsapp.com", "whatsapp.net"]
        ),
        .init(
            id: "signal", name: "Signal", assetName: "platform-signal", tintHex: 0x3A76F0,
            domains: ["signal.org", "www.signal.org", "signal.me"]
        ),
        .init(
            id: "tiktok", name: "TikTok", assetName: "platform-tiktok", tintHex: 0x000000,
            domains: ["tiktok.com", "www.tiktok.com", "tiktokcdn.com", "tiktokv.com", "musical.ly", "byteoversea.com"]
        ),
        .init(
            id: "viber", name: "Viber", assetName: "platform-viber", tintHex: 0x7360F2,
            domains: ["viber.com", "www.viber.com"]
        ),
        .init(
            id: "notion", name: "Notion", assetName: "platform-notion", tintHex: 0x000000,
            domains: ["notion.so", "www.notion.so", "notion.site"]
        ),
    ]
}

nonisolated enum UninstallScope: String, CaseIterable, Identifiable {
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

nonisolated extension Array where Element == StrategyEntry {
    static let bundled: [StrategyEntry] = [
        .init(id: "general-simple-fake", title: "GENERAL (SIMPLE FAKE)", detail: "по умолчанию для Discord"),
        .init(id: "general-fake-tls-auto", title: "GENERAL (FAKE TLS AUTO)", detail: "если SIMPLE FAKE слабо"),
        .init(id: "general-alt", title: "GENERAL (ALT)", detail: "жёсткий DPI"),
    ]
}
