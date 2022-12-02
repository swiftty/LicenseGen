import Foundation

public struct GetVersion: ProxyRequest {
    public init() {}


    public func send() async throws -> String? {
        let pipe = Pipe()

        try shell("/usr/bin/env", "swift", "package", "--version", stdout: pipe)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let str = String(data: data, encoding: .utf8) ?? ""

        let regex = try NSRegularExpression(pattern: #"(\d\.\d\.\d?)"#, options: [])
        let results = regex.matches(in: str, options: [], range: NSRange(str.startIndex..<str.endIndex, in: str))

        guard let result = results.first, let range = Range<String.Index>(result.range, in: str) else {
            return nil
        }
        return String(str[range])
    }
}
