import XCTest
import Foundation
import ArgumentParser
import TSCBasic
import TSCTestSupport
import LicenseGenKit
@testable import LicenseGenCommand

extension Options.Config.Setting: Equatable {
    public static func == (lhs: Options.Config.Setting, rhs: Options.Config.Setting) -> Bool {
        switch (lhs, rhs) {
        case (.ignore, ignore): return true
        case (.licensePath(let lhs), .licensePath(let rhs)): return lhs == rhs
        default: return false
        }
    }
}

extension InMemoryFileSystem: LicenseGenKit.FileIO {
    public func packageVersion() throws -> String {
        "5.3.0"
    }

    public func dumpPackage(at url: URL) throws -> Data {
        try readFileContents(.init(url.appendingPathComponent("Package.swift").path)).withData { data in
            Data(data)
        }
    }

    public func getDirectoryContents(at url: URL) throws -> [URL] {
        try getDirectoryContents(AbsolutePath(url.path))
            .map(url.appendingPathComponent)
    }

    public func createDirectory(at url: URL) throws {
        try createDirectory(.init(url.path), recursive: true)
    }

    public func createTmpDirectory() throws -> URL {
        try createDirectory(.init("/tmp"))
        return URL(fileURLWithPath: "/tmp")
    }

    public func remove(at url: URL) throws {
        try removeFileTree(.init(url.path))
    }

    public func move(_ from: URL, to: URL) throws {
        try move(from: .init(from.path), to: .init(to.path))
    }

    public func readContents(at url: URL) throws -> String {
        try readFileContents(.init(url.path)).validDescription ?? ""
    }

    public func writeContents(_ data: Data, to url: URL) throws {
        try writeFileContents(.init(url.path), bytes: .init(data))
    }

    public func isDirectory(at url: URL) -> Bool {
        isDirectory(.init(url.path))
    }

    public func isExists(at url: URL) -> Bool {
        exists(.init(url.path))
    }
}

final class LicenseGenCommandTests: XCTestCase {

    func testConfigCommandOptions() throws {
        let fs = InMemoryFileSystem()
        try fs.writeFileContents(.init("/.licensegen.yml")) { bytes in
            bytes <<< """
            foo:
              ignore:

            bar:
              ignore: true

            bar2:
              ignore: false

            baz:
              license_path: custom_dir/custom_path
            """
        }
        fileIO = fs

        let opt = try CommandOptions.parse([
            "--settings-bundle",
            "--settings-bundle-prefix", "foo",
            "--config-path", "/"
        ])

        let config = try XCTUnwrap(opt.config)
        XCTAssertEqual(config.modifiers["foo"], .ignore)
        XCTAssertEqual(config.modifiers["bar"], .ignore)
        XCTAssertEqual(config.modifiers["bar2"], nil)
        XCTAssertEqual(config.modifiers["baz"], .licensePath("custom_dir/custom_path"))
    }
}
