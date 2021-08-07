import Foundation

public protocol FileIO {
    func getDirectoryContents(at url: URL) throws -> [URL]

    func dumpPackage(at url: URL) throws -> Data
}

// MARK: -
struct DefaultFileIO: FileIO {
    func getDirectoryContents(at path: URL) throws -> [URL] {
        fatalError("TODO")
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
