import Foundation

public protocol FileIO {
    func isDirectory(at url: URL) -> Bool

    func isExists(at url: URL) -> Bool

    func getDirectoryContents(at url: URL) throws -> [URL]

    func readContents(at url: URL) throws -> String

    func dumpPackage(at url: URL) throws -> Data
}

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

    func readContents(at url: URL) throws -> String {
        try String(contentsOf: url)
    }

    func dumpPackage(at path: URL) throws -> Data {
        let pipe = Pipe()

        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["swift", "package", "dump-package"]
        process.standardOutput = pipe
        process.currentDirectoryURL = path

        process.launch()
        process.waitUntilExit()

        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
}
