import Foundation

public struct Options {
    public var checkoutsPaths: [URL]

    public var packagePaths: [URL]

    public init(
        checkoutsPaths: [URL],
        packagePaths: [URL] = []
    ) {
        self.checkoutsPaths = checkoutsPaths
        self.packagePaths = packagePaths
    }
}
