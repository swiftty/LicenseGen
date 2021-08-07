import Foundation

public struct LicenseGen {
    public init() {}

    public func run(with options: Options) throws {
    }

    func findPackages(in checkoutsPaths: [URL], using fileSystem: FileSystem) throws
    -> [CheckoutPackage] {
        var packages: [CheckoutPackage] = []
        for checkoutsPath in checkoutsPaths {
            for path in try fileSystem.getDirectoryContents(at: checkoutsPath) {
                packages.append(.init(path: path))
            }
        }
        return packages.uniqued(by: \.name).sorted()
    }
}
