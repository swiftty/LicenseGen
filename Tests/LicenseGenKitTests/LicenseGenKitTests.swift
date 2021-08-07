import XCTest
@testable import LicenseGenKit
import TSCBasic
import TSCTestSupport

extension InMemoryFileSystem: LicenseGenKit.FileSystem {
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
        let packages = try LicenseGen().findPackages(in: checkoutsPaths, using: fs)

        XCTAssertEqual(packages.map(\.name), [
            "PackageA",
            "PackageB",
            "PackageC"
        ])
    }
}
