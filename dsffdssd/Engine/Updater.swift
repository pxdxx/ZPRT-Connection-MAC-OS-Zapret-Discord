import Foundation

nonisolated struct GitHubRelease: Decodable, Sendable, Equatable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

/// Checks GitHub Releases for a newer tag than the running build. Updating
/// itself is deliberately not automated - it just points at the release
/// page on GitHub, per explicit request to drop the in-app self-update
/// (privileged download-verify-replace) path.
nonisolated enum Updater {
    static let repo = "pxdxx/ZPRT-Connection-MAC-OS-Zapret-Discord"
    static let releasesPageURL = URL(string: "https://github.com/\(repo)/releases/latest")!

    static func checkLatestRelease(currentVersion: String) async -> GitHubRelease? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=1") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ZPRT-Connection", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data),
              let latest = releases.first,
              isNewer(latest.tagName, than: currentVersion)
        else { return nil }
        return latest
    }

    static func displayVersion(_ version: String) -> String {
        version.first == "v" || version.first == "V" ? String(version.dropFirst()) : version
    }

    /// Plain string/numeric comparison treats "1.4.0" as greater than "1.4"
    /// (longer common-prefix string), so compare version components
    /// numerically instead, padding the shorter one with zeros.
    private static func isNewer(_ candidate: String, than installed: String) -> Bool {
        let c = versionComponents(candidate)
        let i = versionComponents(installed)
        for index in 0..<max(c.count, i.count) {
            let cv = index < c.count ? c[index] : 0
            let iv = index < i.count ? i[index] : 0
            if cv != iv { return cv > iv }
        }
        return false
    }

    private static func versionComponents(_ version: String) -> [Int] {
        displayVersion(version).split(separator: ".").map { Int($0) ?? 0 }
    }
}
