import Foundation

public struct Options {
    public var checkoutsPaths: [URL]

    public var resolvedPaths: [URL]

    public init(
        checkoutsPaths: [URL],
        resolvedPaths: [URL] = []
    ) {
        self.checkoutsPaths = checkoutsPaths
        self.resolvedPaths = resolvedPaths
    }
}
