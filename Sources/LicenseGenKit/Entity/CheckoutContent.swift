import Foundation

struct CheckoutContent: Hashable {
    var path: URL
    var name: String

    init(path: URL) {
        self.path = path
        self.name = path.lastPathComponent
    }
}

extension CheckoutContent: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name < rhs.name
    }
}
