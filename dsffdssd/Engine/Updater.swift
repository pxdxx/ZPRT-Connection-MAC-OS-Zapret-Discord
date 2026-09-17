import Foundation
import CryptoKit

nonisolated struct GitHubRelease: Decodable, Sendable, Equatable {
    let tagName: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

nonisolated struct GitHubReleaseAsset: Decodable, Sendable, Equatable {
    let name: String
    let downloadURL: URL
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
        case digest
    }
}

/// Checks GitHub Releases for a newer build and installs it in place.
/// Modeled on Flowseal's zapret-mac-discord-youtube updater: no paid Apple
/// Developer account needed because the download goes through curl/URLSession
/// (no com.apple.quarantine attribute gets attached, unlike a browser
/// download), so Gatekeeper's "unidentified developer" prompt never re-fires
/// on auto-update the way it does for the very first manual DMG install.
nonisolated enum Updater {
    static let repo = "pxdxx/ZPRT-Connection-MAC-OS-Zapret-Discord"
    static let assetName = "ZPRT-Connection-macOS.zip"

    enum UpdateError: LocalizedError {
        case noAsset
        case digestMismatch
        case badBundle(String)
        case scriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAsset: "В релизе нет файла обновления (\(Updater.assetName))"
            case .digestMismatch: "Контрольная сумма скачанного обновления не совпала"
            case .badBundle(let message): message
            case .scriptFailed(let message): message
            }
        }
    }

    static func checkLatestRelease(currentVersion: String) async -> GitHubRelease? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases?per_page=1") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ZPRT-Connection", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data),
              let latest = releases.first,
              latest.assets.contains(where: { $0.name == assetName }),
              isNewer(latest.tagName, than: currentVersion)
        else { return nil }
        return latest
    }

    static func displayVersion(_ version: String) -> String {
        version.first == "v" || version.first == "V" ? String(version.dropFirst()) : version
    }

    private static func isNewer(_ candidate: String, than installed: String) -> Bool {
        displayVersion(candidate).compare(displayVersion(installed), options: [.numeric, .caseInsensitive]) == .orderedDescending
    }

    /// Downloads, verifies, and installs `release` over the running app, then
    /// relaunches it. Returns once the replace-and-relaunch has been handed
    /// off to a detached background script — the caller should terminate the
    /// app right after this returns successfully.
    static func install(_ release: GitHubRelease) async throws {
        guard let asset = release.assets.first(where: { $0.name == assetName }) else {
            throw UpdateError.noAsset
        }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("zprt-update-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let archive = work.appendingPathComponent(assetName)
        let (downloaded, response) = try await URLSession.shared.download(
            for: URLRequest(url: asset.downloadURL, timeoutInterval: 120)
        )
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.badBundle("Не удалось скачать обновление")
        }
        try fm.moveItem(at: downloaded, to: archive)

        if let digest = asset.digest, digest.hasPrefix("sha256:") {
            let data = try Data(contentsOf: archive, options: .mappedIfSafe)
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard actual.caseInsensitiveCompare(String(digest.dropFirst(7))) == .orderedSame else {
                throw UpdateError.digestMismatch
            }
        }

        let extracted = work.appendingPathComponent("extracted", isDirectory: true)
        try fm.createDirectory(at: extracted, withIntermediateDirectories: true)
        let unzip = Shell.run(["/usr/bin/ditto", "-x", "-k", archive.path, extracted.path], timeoutSeconds: 60)
        guard unzip.ok else { throw UpdateError.badBundle("Не удалось распаковать обновление") }

        let newApp = extracted.appendingPathComponent("ZPRT Connection.app", isDirectory: true)
        guard fm.fileExists(atPath: newApp.path),
              let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let newVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              displayVersion(newVersion) == displayVersion(release.tagName)
        else {
            throw UpdateError.badBundle("Архив обновления повреждён или содержит не ту версию")
        }
        let verify = Shell.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", newApp.path], timeoutSeconds: 30)
        guard verify.ok else { throw UpdateError.badBundle("Подпись обновления не прошла проверку") }

        let target = Bundle.main.bundleURL.standardizedFileURL
        guard target.pathExtension == "app" else {
            throw UpdateError.badBundle("Не удалось определить путь установленного приложения")
        }

        // Stage the new app somewhere stable (outside `work`, which we clean
        // up on return) so the background worker still has it after this
        // function's `defer` fires.
        let stagedRoot = fm.temporaryDirectory.appendingPathComponent("zprt-update-staged-\(UUID().uuidString)", isDirectory: true)
        let stagedApp = stagedRoot.appendingPathComponent("ZPRT Connection.app", isDirectory: true)
        try fm.createDirectory(at: stagedRoot, withIntermediateDirectories: true)
        try fm.copyItem(at: newApp, to: stagedApp)

        let ownerID = "\(getuid()):\(getgid())"
        let outerScript = """
        #!/bin/sh
        set -eu
        STAGED_ROOT=$1
        NEW_APP=$2
        TARGET=$3
        OWNER=$4
        PID=$5
        LOG=/tmp/zprt-updater.log
        WORKER=$(/usr/bin/mktemp /tmp/zprt-updater-worker.XXXXXX.sh)
        cat > "$WORKER" <<'WORKER_EOF'
        #!/bin/sh
        STAGED_ROOT=$1
        NEW_APP=$2
        TARGET=$3
        OWNER=$4
        PID=$5
        I=0
        while /bin/kill -0 "$PID" 2>/dev/null; do
            I=$((I + 1))
            if [ "$I" -gt 100 ]; then break; fi
            sleep 0.1
        done
        BACKUP="$TARGET.bak-$$"
        rm -rf "$BACKUP"
        if [ -d "$TARGET" ]; then mv "$TARGET" "$BACKUP"; fi
        if /usr/bin/ditto "$NEW_APP" "$TARGET"; then
            chown -R "$OWNER" "$TARGET"
            rm -rf "$BACKUP" "$STAGED_ROOT"
            RUN_USER=$(/usr/bin/stat -f '%Su' "$TARGET" 2>/dev/null || echo root)
            /usr/bin/sudo -u "$RUN_USER" /usr/bin/open "$TARGET"
        else
            rm -rf "$TARGET"
            if [ -d "$BACKUP" ]; then mv "$BACKUP" "$TARGET"; fi
            rm -rf "$STAGED_ROOT"
        fi
        rm -f "$0"
        WORKER_EOF
        /bin/chmod 700 "$WORKER"
        /usr/bin/nohup /bin/sh "$WORKER" "$STAGED_ROOT" "$NEW_APP" "$TARGET" "$OWNER" "$PID" >"$LOG" 2>&1 </dev/null &
        disown 2>/dev/null || true
        exit 0
        """
        let result = try PrivilegeRunner.runScript(
            outerScript,
            args: [stagedRoot.path, stagedApp.path, target.path, ownerID, String(ProcessInfo.processInfo.processIdentifier)],
            timeoutSeconds: 30
        )
        guard result.ok else {
            try? fm.removeItem(at: stagedRoot)
            throw UpdateError.scriptFailed(result.lastLine.isEmpty ? result.output : result.lastLine)
        }
    }
}
