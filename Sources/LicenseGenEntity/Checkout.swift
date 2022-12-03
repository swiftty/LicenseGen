import Foundation

public struct Checkout: Hashable {
    public var path: URL
    public var name: String { path.lastPathComponent }

    public init(path: URL) {
        self.path = path
    }
}

extension Checkout: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name < rhs.name
    }
}
