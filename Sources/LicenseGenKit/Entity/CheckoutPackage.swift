import Foundation

struct CheckoutPackage {
    var path: URL
    var name: String

    init(path: URL) {
        self.path = path
        self.name = path.lastPathComponent
    }
}

extension CheckoutPackage: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name < rhs.name
    }
}
