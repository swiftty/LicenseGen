import Foundation

public struct GetVersion: ProxyRequest {
    public enum Error: Swift.Error {
        case unknownVersion(String)
    }

    public init() {}

    public func send(using io: ProcessIO) async throws -> String {
        let shell = io.shell("/usr/bin/env", "swift", "package", "--version")
        let data = try await shell()
        let str = String(data: data, encoding: .utf8) ?? ""

        let regex = try NSRegularExpression(pattern: #"(\d\.\d\.\d?)"#, options: [])
        let results = regex.matches(in: str, options: [], range: NSRange(str.startIndex..<str.endIndex, in: str))

        guard let result = results.first, let range = Range<String.Index>(result.range, in: str) else {
            throw Error.unknownVersion(str)
        }
        return String(str[range])
    }
}
