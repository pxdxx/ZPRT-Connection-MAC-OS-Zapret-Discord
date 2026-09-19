import Foundation

nonisolated enum DNSChoice: String, CaseIterable, Identifiable, Sendable {
    case system
    case cloudflare
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Стандартный"
        case .cloudflare: "Cloudflare · 1.1.1.1"
        case .google: "Google · 8.8.8.8"
        }
    }

    /// Empty means "automatic" (whatever the router/ISP hands out over DHCP).
    var addresses: [String] {
        switch self {
        case .system: []
        case .cloudflare: ["1.1.1.1", "1.0.0.1"]
        case .google: ["8.8.8.8", "8.8.4.4"]
        }
    }
}

nonisolated struct DNSState: Equatable, Sendable {
    /// Network service name as macOS knows it, e.g. "Wi-Fi".
    let service: String
    let servers: [String]
    /// nil when the current servers match none of our presets (set by hand or a VPN).
    let choice: DNSChoice?
}

nonisolated enum DNSService {
    static func read() -> DNSState? {
        guard let service = activeService() else { return nil }
        let result = Shell.run(["/usr/sbin/networksetup", "-getdnsservers", service], timeoutSeconds: 5)
        guard result.ok else { return nil }
        let servers = parseServers(result.output)
        return DNSState(service: service, servers: servers, choice: match(servers))
    }

    static func apply(_ choice: DNSChoice, service: String) throws -> CommandResult {
        let script = """
        #!/bin/sh
        set -eu
        SERVICE=$1
        shift
        /usr/sbin/networksetup -setdnsservers "$SERVICE" "$@"
        /usr/bin/dscacheutil -flushcache || true
        /usr/bin/killall -HUP mDNSResponder || true
        """
        let servers = choice.addresses.isEmpty ? ["Empty"] : choice.addresses
        return try PrivilegeRunner.runScript(script, args: [service] + servers, timeoutSeconds: 60)
    }

    // MARK: - Parsing

    /// The service that carries the default route; falls back to the first
    /// enabled ethernet/Wi-Fi service if a VPN owns the default route.
    private static func activeService() -> String? {
        let order = Shell.run(["/usr/sbin/networksetup", "-listnetworkserviceorder"], timeoutSeconds: 5)
        guard order.ok else { return nil }
        let services = parseServiceOrder(order.output)

        let route = Shell.run(["/sbin/route", "-n", "get", "default"], timeoutSeconds: 5)
        let iface = route.output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("interface:") }
            .map { $0.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces) }

        if let iface, let hit = services.first(where: { $0.device == iface }) {
            return hit.name
        }
        return services.first(where: { $0.device.hasPrefix("en") })?.name
    }

    static func parseServiceOrder(_ text: String) -> [(name: String, device: String)] {
        var result: [(name: String, device: String)] = []
        var pendingName: String?
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("(Hardware Port:") {
                if let name = pendingName {
                    let device = line
                        .components(separatedBy: "Device:").last?
                        .trimmingCharacters(in: CharacterSet(charactersIn: ") ")) ?? ""
                    result.append((name, device))
                }
                pendingName = nil
            } else if line.hasPrefix("("), let close = line.firstIndex(of: ")") {
                let marker = line[line.index(after: line.startIndex)..<close]
                // "(*)" marks a disabled service, digits mark an enabled one.
                pendingName = marker == "*" ? nil : String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    static func parseServers(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" ") && ($0.contains(".") || $0.contains(":")) }
    }

    static func match(_ servers: [String]) -> DNSChoice? {
        let set = Set(servers)
        return DNSChoice.allCases.first { Set($0.addresses) == set }
    }
}
