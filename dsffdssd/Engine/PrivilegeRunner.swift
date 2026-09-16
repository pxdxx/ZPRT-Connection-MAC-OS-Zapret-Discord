import Foundation

nonisolated enum PrivilegeRunner {
    private static let cancelToken = "-128"

    static func runScript(_ script: String, args: [String] = [], timeoutSeconds: TimeInterval = 300) throws -> CommandResult {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("outpost-priv-\(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: temp) }
        try script.write(to: temp, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temp.path)
        return try runScriptFile(temp, args: args, timeoutSeconds: timeoutSeconds)
    }

    static func runScriptFile(_ file: URL, args: [String] = [], timeoutSeconds: TimeInterval = 300) throws -> CommandResult {
        let apple = [
            "on run argv",
            "set cmd to \"/bin/sh\"",
            "repeat with a in argv",
            "set cmd to cmd & \" \" & quoted form of (a as text)",
            "end repeat",
            "do shell script cmd & \" 2>&1\" with administrator privileges",
            "end run",
        ]
        var argv = ["/usr/bin/osascript"]
        for line in apple {
            argv.append(contentsOf: ["-e", line])
        }
        argv.append(file.path)
        argv.append(contentsOf: args)

        let result = Shell.run(argv, timeoutSeconds: timeoutSeconds)
        if !result.ok, result.output.contains(cancelToken) {
            throw EngineError.cancelled
        }
        return result
    }

    /// Prefer passwordless sudo helpers after install-sudoers.
    static func runPasswordless(_ executable: URL, args: [String] = []) -> CommandResult {
        Shell.run(["/usr/bin/sudo", "-n", executable.path] + args)
    }
}

nonisolated enum Shell {
    static func run(_ args: [String], timeoutSeconds: TimeInterval = 120) -> CommandResult {
        guard let launch = args.first else {
            return CommandResult(ok: false, output: "empty command")
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launch)
        task.arguments = Array(args.dropFirst())
        let out = Pipe()
        task.standardOutput = out
        task.standardError = out
        do {
            try task.run()
        } catch {
            return CommandResult(ok: false, output: error.localizedDescription)
        }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            task.waitUntilExit()
            group.leave()
        }
        _ = group.wait(timeout: .now() + timeoutSeconds)
        if task.isRunning {
            task.terminate()
            return CommandResult(ok: false, output: "timeout")
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return CommandResult(ok: task.terminationStatus == 0, output: text)
    }
}
