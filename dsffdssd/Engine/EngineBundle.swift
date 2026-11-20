import Foundation

/// Xcode flattens `Resources/engine` into `Contents/Resources`.
/// Rebuild the tree the stock install.sh / run.sh expect.
nonisolated enum EngineBundle {
    static var stagingRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Outpost/payload")
    }

    /// App version + build; changes on every release that may ship new strategies or fakes.
    static var bundledEngineVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    static func materialize() throws -> URL {
        let fm = FileManager.default
        guard let resources = Bundle.main.resourceURL else {
            throw EngineError.missingPayload
        }

        let root = stagingRoot
        if fm.fileExists(atPath: root.path) {
            try fm.removeItem(at: root)
        }
        try fm.createDirectory(at: root.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("strategies"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("default-lists"), withIntermediateDirectories: true)

        let rootFiles = [
            "install.sh", "install-sudoers.sh", "run.sh", "restart.sh", "stop.sh",
            "uninstall.sh", "watchdog.sh", "strategies.tsv",
            "org.zapret.macos.engine.plist.in", "ipset-any.txt", "ipset-none.txt",
        ]
        for name in rootFiles {
            try copyIfExists(from: resources.appendingPathComponent(name), to: root.appendingPathComponent(name))
        }

        // Copy every bundled fake payload instead of a hand-kept list: upstream
        // rotates fakes (max_ru -> www_sferum_ru), and a missing .bin makes
        // utunws fail to start on every strategy that references it.
        try copyIfExists(from: resources.appendingPathComponent("utunws"), to: root.appendingPathComponent("bin/utunws"))
        if let items = try? fm.contentsOfDirectory(atPath: resources.path) {
            for name in items where name.hasSuffix(".bin") {
                try copyIfExists(from: resources.appendingPathComponent(name), to: root.appendingPathComponent("bin/\(name)"))
            }
        }

        // Installed copy of this marker tells the app whether /Library/.../Zapret
        // still runs strategies/fakes from an older app version.
        try bundledEngineVersion.write(
            to: root.appendingPathComponent(EnginePaths.engineVersionFileName),
            atomically: true,
            encoding: .utf8
        )

        let lists = [
            "ipset-all.txt", "ipset-exclude-user.txt", "ipset-exclude.txt",
            "list-exclude-user.txt", "list-exclude.txt",
            "list-general-user.txt", "list-general.txt", "list-google.txt",
        ]
        for name in lists {
            try copyIfExists(
                from: resources.appendingPathComponent(name),
                to: root.appendingPathComponent("default-lists/\(name)")
            )
        }

        // strategy templates
        if let items = try? fm.contentsOfDirectory(atPath: resources.path) {
            for name in items where name.hasSuffix(".conf.in") {
                try copyIfExists(
                    from: resources.appendingPathComponent(name),
                    to: root.appendingPathComponent("strategies/\(name)")
                )
            }
        }

        // permissions
        let exec = [
            "install.sh", "install-sudoers.sh", "run.sh", "restart.sh", "stop.sh",
            "uninstall.sh", "watchdog.sh", "bin/utunws",
        ]
        for rel in exec {
            let path = root.appendingPathComponent(rel).path
            if fm.fileExists(atPath: path) {
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            }
        }

        guard fm.isExecutableFile(atPath: root.appendingPathComponent("bin/utunws").path),
              fm.fileExists(atPath: root.appendingPathComponent("run.sh").path) else {
            throw EngineError.missingPayload
        }
        return root
    }

    private static func copyIfExists(from: URL, to: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: from.path) else { return }
        if fm.fileExists(atPath: to.path) {
            try fm.removeItem(at: to)
        }
        try fm.copyItem(at: from, to: to)
    }
}
