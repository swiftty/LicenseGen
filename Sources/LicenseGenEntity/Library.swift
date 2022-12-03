import Foundation

public protocol Library {
    var checkout: Checkout { get }
    var name: String { get }
}

// MARK: -
public struct SpecifiedLibrary: Hashable, Library {
    public var checkout: Checkout
    public var name: String

    public init(
        checkout: Checkout,
        name: String
    ) {
        self.checkout = checkout
        self.name = name
    }
}

extension Checkout: Library {
    public var checkout: Checkout { self }
}
