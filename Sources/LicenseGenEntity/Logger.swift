import Foundation
import Logging

public enum TaskValues {
    @TaskLocal public static var logger: Logger?
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

public func logging<R>(
    function: StaticString = #function, line: UInt = #line,
    _ body: () async throws -> R
) async rethrows -> R {
    do {
        return try await body()
    } catch {
        TaskValues.logger?.critical("Unexpected error, \(error) [\(function)L:\(line)]")
        throw error
    }
}
