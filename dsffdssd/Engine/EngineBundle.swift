import Foundation

/// Xcode flattens `Resources/engine` into `Contents/Resources`.
/// Rebuild the tree the stock install.sh / run.sh expect.
nonisolated enum EngineBundle {
    static var stagingRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Outpost/payload")
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

        let binFiles = [
            "utunws",
            "ACTIVE_DISCORD_UDP.bin",
            "quic_initial_www_google_com.bin",
            "stun.bin", "stun2.bin",
            "tls_clienthello_4pda_to.bin",
            "tls_clienthello_max_ru.bin",
            "tls_clienthello_sochi_park.bin",
            "tls_clienthello_www_google_com.bin",
        ]
        for name in binFiles {
            try copyIfExists(from: resources.appendingPathComponent(name), to: root.appendingPathComponent("bin/\(name)"))
        }

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
