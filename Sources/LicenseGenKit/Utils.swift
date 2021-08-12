import Foundation

extension Array {
    func uniqued<H: Hashable>(by target: (Element) -> H) -> [Element] {
        var set: Set<H> = []
        return filter { e in
            let key = target(e)
            defer { set.insert(key) }
            return !set.contains(key)
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        uniqued(by: { $0 })
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
