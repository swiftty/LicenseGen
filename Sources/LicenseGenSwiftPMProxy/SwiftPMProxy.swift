import Foundation
import Logging

public protocol ProxyRequest {
    associatedtype Response

    func send() async throws -> Response
}

public enum TaskValues {
    @TaskLocal static var logger: Logger?
}

public func logging<R>(
    function: StaticString = #function, line: UInt = #line,
    _ body: () throws -> R
) rethrows -> R {
    do {
        return try body()
    } catch {
        TaskValues.logger?.critical("Unexpected error, \(error) [\(function)L:\(line)]")
        throw error
    }
}

@discardableResult
func shell(
    _ launchPath: String,
    _ arguments: String...,
    currentDirectoryURL: URL? = nil,
    stdout: Any? = nil
) throws -> Process {
    try shell(URL(fileURLWithPath: launchPath), arguments,
              currentDirectoryURL: currentDirectoryURL,
              stdout: stdout)
}

@discardableResult
func shell(
    _ executableURL: URL,
    _ arguments: String...,
    currentDirectoryURL: URL? = nil,
    stdout: Any? = nil
) throws -> Process {
    try shell(executableURL, arguments,
              currentDirectoryURL: currentDirectoryURL,
              stdout: stdout)
}

@discardableResult
private func shell(
    _ executableURL: URL,
    _ arguments: [String],
    currentDirectoryURL: URL? = nil,
    stdout: Any? = nil
) throws -> Process {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL
    process.standardOutput = stdout

    try process.run()

    return process
}
