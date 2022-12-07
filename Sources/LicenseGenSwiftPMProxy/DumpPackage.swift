import Foundation
import LicenseGenEntity

public struct DumpPackage: ProxyRequest {
    public let path: URL
    public let spmVersion: String

    public init(path: URL, spmVersion: String) {
        self.path = path
        self.spmVersion = spmVersion
    }

    public func send(using io: any ProcessIO) async throws -> Package {
        let data = try await logging { try await readData(using: io) }
        let decoder = PackageDecoder.from(spmVersion)
        let decoded = try logging { try decoder.decode(from: data) }

        return Package(
            name: decoded.name,
            products: decoded.products.map { p in
                .init(name: p.name, targets: p.targets)
            },
            dependencies: decoded.dependencies.map { d in
                .init(identity: d.name, displayName: d.displayName, location: .remote(d.url))
            },
            targets: decoded.targets.map { t in
                .init(name: t.name, dependencies: t.dependencies.map { d in
                    switch d {
                    case .byName(let name): return .byName(name)
                    case .product(let name, let package): return .product(name: name, package: package)
                    case .target(let name): return .target(name: name)
                    }
                })
            }
        )
    }

    private func readData(using io: any ProcessIO) async throws -> Data {
        var shell = io.shell("/usr/bin/env", "swift", "package", "dump-package")
        shell.currentDirectoryURL = path

        return try await shell()
    }
}

// MARK: - decoder
private struct PackageDecoder {
    static func from(_ version: String) -> PackageDecoder {
        func findDecoder() -> (Data, JSONDecoder) throws -> PackageDescription {
            func make<D: Decodable>(_ type: D.Type) -> (Data, JSONDecoder) throws -> D {
                return { try $1.decode(type, from: $0) }
            }

            if case let d = PackageDescription5_6.self, d.isOlder(than: version) {
                return make(d)
            } else if case let d = PackageDescription5_5.self, d.isOlder(than: version) {
                return make(d)
            }
            return make(PackageDescription5_3.self)
        }
        return self.init(decoder: findDecoder())
    }

    private let decoder: (Data, JSONDecoder) throws -> PackageDescription

    func decode(from data: Data) throws -> PackageDescription {
        try decoder(data, JSONDecoder())
    }
}

private protocol PackageDescription {
    static var version: String { get }
    var name: String { get }
    var products: [PackageProduct] { get }
    var dependencies: [PackageDependency] { get }
    var targets: [PackageTarget] { get }
}

private struct PackageProduct: Decodable {
    var name: String
    var targets: [String]
}

private struct PackageDependency: Decodable {
    var name: String
    var displayName: String?
    var url: URL
}

private struct PackageTarget: Decodable {
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

private extension PackageDescription {
    static func isOlder(than target: String) -> Bool {
        target.compare(version, options: .numeric) != .orderedAscending
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

// MARK: - 5.5
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
                PackageDependency(name: $0.identity, displayName: $0.name, url: $0.location)
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

// MARK: - 5.6~
private struct PackageDescription5_6: PackageDescription, Decodable {
    static let version = "5.6"

    var name: String
    var products: [PackageProduct]
    var targets: [PackageTarget]
    var dependencies: [PackageDependency] {
        _dependencies
            .flatMap(\.values)
            .flatMap { $0 }
            .map {
                PackageDependency(name: $0.identity,
                                  displayName: $0.nameForTargetDependencyResolutionOnly,
                                  url: ($0.location.remote?.first ?? $0.location.local?.first)!)
            }
    }

    private var _dependencies: [[String: [SCM]]]

    private enum CodingKeys: String, CodingKey {
        case name, products, targets, _dependencies = "dependencies"
    }

    struct SCM: Decodable {
        var identity: String
        var nameForTargetDependencyResolutionOnly: String?
        var location: Location

        struct Location: Decodable {
            var remote: [URL]?
            var local: [URL]?
        }
    }
}
