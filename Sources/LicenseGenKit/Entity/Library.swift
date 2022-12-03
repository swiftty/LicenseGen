import Foundation
import LicenseGenEntity

protocol Library {
    var checkout: Checkout { get }
    var name: String { get }
}

// MARK: -
struct SpecifiedLibrary: Hashable, Library {
    var checkout: Checkout
    var name: String
}

extension Checkout: Library {
    var checkout: Checkout { self }
}
