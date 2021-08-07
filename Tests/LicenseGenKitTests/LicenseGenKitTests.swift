import XCTest
@testable import LicenseGenKit
import TSCBasic
import TSCTestSupport

extension InMemoryFileSystem: LicenseGenKit.FileIO {
    public func dumpPackage(at url: URL) throws -> Data {
        try readFileContents(.init(url.path)).withData { data in
            data
        }
    }

    public func getDirectoryContents(at url: URL) throws -> [URL] {
        try getDirectoryContents(AbsolutePath(url.path))
            .map(URL.init(fileURLWithPath:))
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
        let contents = try LicenseGen().findCheckoutContents(in: checkoutsPaths, using: fs)

        XCTAssertEqual(contents.map(\.name), [
            "PackageA",
            "PackageB",
            "PackageC"
        ])
    }

    func testCollectLibraries() throws {
        let fs = InMemoryFileSystem()
        try fs.writeFileContents(.init("/Package.swift"),
                                 fixture: "collect_library/Package.swift.json")
        try fs.writeFileContents(.init("/checkouts/LicenseGen/Package.swift"),
                                 fixture: "collect_library/LicenseGen.Package.swift.json")
        try fs.writeFileContents(.init("/checkouts/swift-argument-parser/Package.swift"),
                                 fixture: "collect_library/ArgumentParser.Package.swift.json")

        let checkouts = [
            CheckoutContent(path: URL(fileURLWithPath: "/checkouts/LicenseGen")),
            CheckoutContent(path: URL(fileURLWithPath: "/checkouts/swift-argument-parser"))
        ]

        let rootPackagePath = URL(fileURLWithPath: "/")
        let results = try LicenseGen().collectLibraries(for: rootPackagePath, with: checkouts, using: fs)

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
