import Foundation

public protocol FileSystem {
    func getDirectoryContents(at path: URL) throws -> [URL]
}
