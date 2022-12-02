import XCTest
@testable import LicenseGenSwiftPMProxy

final class LicenseGenSwiftPMProxyTests: XCTestCase {
    func testDumpPackage() async throws {
        let request = DumpPackage(
            path: URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
            spmVersion: "5.7")

        let package = try await request.send()

        XCTAssertEqual(package.name, "LicenseGen")
        XCTAssertEqual(package.products.count, 2)
        XCTAssertEqual(package.dependencies.count, 5)
    }
}
