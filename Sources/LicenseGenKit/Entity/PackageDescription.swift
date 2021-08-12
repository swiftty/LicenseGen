import Foundation

struct PackageVersion: RawRepresentable {
    enum Error: Swift.Error {
        case unknownPackageVersion(String)
    }

    var rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    func loadDescription(from data: Data) throws -> PackageDescription {
        if rawValue.compare(PackageDescription5_5.version, options: .numeric) != .orderedAscending {
            return try JSONDecoder().decode(PackageDescription5_5.self, from: data)
        }
        return try JSONDecoder().decode(PackageDescription5_3.self, from: data)
    }
}

protocol PackageDescription {
    var name: String { get }
    var products: [PackageProduct] { get }
    var dependencies: [PackageDependency] { get }
    var targets: [PackageTarget] { get }
}

struct PackageProduct: Decodable {
    var name: String
    var targets: [String]
}

struct PackageDependency: Decodable {
    var name: String
    var url: URL
}

struct PackageTarget: Decodable {
    var name: String
    var dependencies: [Dependency]

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

// MARK: - 5.3~
private struct PackageDescription5_3: PackageDescription, Decodable {
    static let version = "5.3"

    var name: String
    var products: [PackageProduct]
    var targets: [PackageTarget]
    var dependencies: [PackageDependency]
}

// MARK: - 5.5~
private struct PackageDescription5_5: PackageDescription, Decodable {
    static let version = "5.5"

    var name: String
    var products: [PackageProduct]
    var targets: [PackageTarget]
    var dependencies: [PackageDependency] {
        _dependencies
            .flatMap(\.values)
            .flatMap { $0 }
            .map {
                PackageDependency(name: $0.name ?? $0.identity, url: $0.location)
            }
    }

    private var _dependencies: [[String: [SCM]]]

    private enum CodingKeys: String, CodingKey {
        case name, products, targets, _dependencies = "dependencies"
    }

    struct SCM: Decodable {
        var identity: String
        var name: String?
        var location: URL
    }
}
