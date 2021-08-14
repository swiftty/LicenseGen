import Foundation

public protocol FileIO {
    func isDirectory(at url: URL) -> Bool

    func isExists(at url: URL) -> Bool

    func getDirectoryContents(at url: URL) throws -> [URL]

    func createDirectory(at url: URL) throws

    func move(_ from: URL, to: URL) throws

    func remove(at url: URL) throws

    func readContents(at url: URL) throws -> String

    func writeContents(_ data: Data, to url: URL) throws

    func dumpPackage(at url: URL) throws -> Data

    func createTmpDirectory() throws -> URL
}

public func defaultFileIO() -> FileIO { DefaultFileIO() }

// MARK: -
struct DefaultFileIO: FileIO {
    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    func isExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func getDirectoryContents(at path: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [])
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
    }

    func createTmpDirectory() throws -> URL {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(UUID().uuidString.prefix(6).lowercased())")
        try createDirectory(at: tmp)
        return tmp
    }

    func move(_ from: URL, to: URL) throws {
        try FileManager.default.moveItem(at: from, to: to)
    }

    func remove(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    func readContents(at url: URL) throws -> String {
        try String(contentsOf: url)
    }

    func writeContents(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func dumpPackage(at path: URL) throws -> Data {
        let pipe = Pipe()

        try shell("/usr/bin/env", "swift", "package", "dump-package",
                  currentDirectoryURL: path,
                  stdout: pipe)

        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
}
