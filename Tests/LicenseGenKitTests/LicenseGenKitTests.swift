import XCTest
@testable import LicenseGenKit
@testable import LicenseGenSwiftPMProxy
import LicenseGenEntity
import TSCBasic
import TSCTestSupport

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

extension InMemoryFileSystem: LicenseGenSwiftPMProxy.ProcessIO {
    public func shell(_ launchPath: String, _ arguments: String...) -> Shell {
        Shell(launchPath: launchPath, arguments: arguments) { shell in
            if arguments.contains("dump-package") {
                let url = shell.currentDirectoryURL?.appendingPathComponent("Package.swift")
                return try self.readFileContents(.init(url?.path ?? "")).withData { data in
                    Data(data)
                }
            } else if arguments.contains("--version") {
                return "5.3.0".data(using: .utf8) ?? Data()
            } else {
                return Data()
            }
        }
    }
}

final class LicenseGenKitTests: XCTestCase {

    func testFindCheckoutPackages() throws {
        let fs = InMemoryFileSystem(emptyFiles:
            "/checkoutsA/PackageA/LICENSE",
            "/checkoutsA/PackageB/LICENSE",
            "/checkoutsB/PackageA/LICENSE",
            "/checkoutsB/PackageC/LICENSE"
        )
        let checkoutsPaths = [
            URL(fileURLWithPath: "/checkoutsA"),
            URL(fileURLWithPath: "/checkoutsB")
        ]
        let contents = try LicenseGen.findCheckoutContents(in: checkoutsPaths, using: fs)

        XCTAssertEqual(contents.map(\.name), [
            "PackageA",
            "PackageB",
            "PackageC"
        ])
    }

    func testCollectLibraries() async throws {
        let fs = InMemoryFileSystem()
        try fs.writeFileContents(.init("/Package.swift"),
                                 fixture: "collect_library/Package.swift.json")
        try fs.writeFileContents(.init("/checkouts/LicenseGen/Package.swift"),
                                 fixture: "collect_library/LicenseGen.Package.swift.json")
        try fs.writeFileContents(.init("/checkouts/swift-argument-parser/Package.swift"),
                                 fixture: "collect_library/ArgumentParser.Package.swift.json")

        let checkouts = [
            Checkout(path: URL(fileURLWithPath: "/checkouts/LicenseGen")),
            Checkout(path: URL(fileURLWithPath: "/checkouts/swift-argument-parser"))
        ]

        let rootPackagePath = URL(fileURLWithPath: "/")
        let results = try await LicenseGen.collectLibraries(for: rootPackagePath,
                                                            spmVersion: "5.3.0",
                                                            with: checkouts,
                                                            using: fs)

        XCTAssertEqual(Set(results.map(\.name)), [
            "licensegen",
            "LicenseGenKit",
            "ArgumentParser"
        ])
    }
}

private extension FileSystem {
    func writeFileContents(_ path: AbsolutePath, fixture: String) throws {
        let content = try open(fixture)
        try writeFileContents(path) { stream in
            stream.write(content)
        }
    }
}

private func open(_ path: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures")
        .appendingPathComponent(path)
    return try String(contentsOf: url)
}
