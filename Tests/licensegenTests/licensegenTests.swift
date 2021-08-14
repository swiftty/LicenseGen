import XCTest
import Foundation
import ArgumentParser
@testable import licensegen
@testable import LicenseGenKit

final class LicensegenTests: XCTestCase {

    func testLicensegen() throws {
        // Mac Catalyst won't have `Process`, but it is supported for executables.
        #if !targetEnvironment(macCatalyst)

        let workingDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")

        try prepareCheckouts(at: workingDir)

        let licensegen = productsDirectory.appendingPathComponent("licensegen")

        let pipe = Pipe()

        let process = try shell(
            licensegen,
            "--checkouts-path",
            ".build/checkouts",
            "--package-paths",
            ".",
            "--settings-bundle",
            "--settings-bundle-prefix",
            "example",
            "--output-path",
            "Settings.bundle",
            currentDirectoryURL: workingDir,
            stdout: pipe)

        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0)

        let outputPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures")
            .appendingPathComponent("Settings.bundle")

        struct Item: Decodable {
            var file: String?

            private enum CodingKeys: String, CodingKey {
                case file = "File"
            }
        }

        let items = try PropertyListDecoder()
            .decode([String: [Item]].self,
                    from: Data(contentsOf: outputPath
                                .appendingPathComponent("example.plist")))
            .first?.value.dropFirst()

        let fs = FileManager.default
        let contents = try fs.contentsOfDirectory(
            atPath: outputPath.appendingPathComponent("example").path)

        XCTAssertFalse(contents.isEmpty)

        XCTAssertEqual(
            Set(contents),
            Set(
               items?
                .compactMap(\.file)
                .map {
                    $0.replacingOccurrences(of: "example/", with: "") + ".plist"
                } ?? []
            )
        )

        #endif
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
        #else
        return Bundle.main.bundleURL
        #endif
    }
}

private func prepareCheckouts(at path: URL) throws {
    let process = try shell("/usr/bin/env", "swift", "package", "resolve",
                            currentDirectoryURL: path,
                            stdout: FileHandle.standardError)
    process.waitUntilExit()

    XCTAssertEqual(process.terminationStatus, 0)
}
