import Foundation

protocol Library {
    var checkout: CheckoutContent { get }
    var name: String { get }
}

// MARK: -
struct SpecifiedLibrary: Hashable, Library {
    var checkout: CheckoutContent
    var name: String
}

extension CheckoutContent: Library {
    var checkout: CheckoutContent { self }
}
