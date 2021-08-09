import Foundation

struct PackageDescription: Decodable {
    var name: String
    var products: [Product]
    var targets: [Target]

    struct Product: Decodable {
        var name: String
        var targets: [String]
    }
    struct Target: Decodable {
        var name: String
        var dependencies: [Dependency]
    }
    enum Dependency: Decodable, Equatable, Comparable {
        case target(name: String)
        case product(name: String, package: String?)
        case byName(String)

        private enum CodingKeys: String, CodingKey {
            case target, product, byName
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            guard let key = values.allKeys.first(where: values.contains) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Did not find a matching key"))
            }
            switch key {
            case .target:
                var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
                self = try .target(name: unkeyedValues.decode(String.self))
            case .product:
                var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
                self = try .product(name: unkeyedValues.decode(String.self),
                                    package: unkeyedValues.decodeIfPresent(String.self))
            case .byName:
                var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
                self = try .byName(unkeyedValues.decode(String.self))
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.byName(let lhs), .byName(let rhs)): return lhs < rhs
            case (.target(let lhs), .target(let rhs)): return lhs < rhs
            case (.product(let lhs0, let lhs1),
                  .product(let rhs0, let rhs1)): return (lhs1 ?? "") < (rhs1 ?? "") && lhs0 < rhs0
            case (.byName, .target): return true
            case (.byName, .product): return true
            case (.target, .product): return true
            default: return false
            }
        }
    }
}
