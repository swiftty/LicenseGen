import Foundation

public protocol ProcessIO {
    func shell(
        _ launchPath: String,
        _ arguments: String...
    ) -> Shell
}

public struct Shell {
    public var launchPath: String
    public var arguments: [String]
    public var currentDirectoryURL: URL?

    var execute: (Shell) async throws -> Data

    public func callAsFunction() async throws -> Data {
        try await execute(self)
    }
}

extension Shell {
    public init(launchPath: String, arguments: [String], currentDirectoryURL: URL? = nil) {
        self.launchPath = launchPath
        self.arguments = arguments
        self.currentDirectoryURL = currentDirectoryURL
        self.execute = { shell in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell.launchPath)
            process.arguments = shell.arguments
            process.currentDirectoryURL = shell.currentDirectoryURL

            let stdout = Pipe()
            process.standardOutput = stdout

            try process.run()

            return stdout.fileHandleForReading.readDataToEndOfFile()
        }
    }
}

public let processIO: some ProcessIO = DefaultProcessIO()

// MARK: - private
private struct DefaultProcessIO: ProcessIO {
    func shell(_ launchPath: String, _ arguments: String...) -> Shell {
        Shell(launchPath: launchPath, arguments: arguments)
    }
}
