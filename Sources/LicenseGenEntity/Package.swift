import Foundation

public struct Package {
    public var name: String
    public var products: [Product]
    public var dependencies: [Dependency]
    public var targets: [Target]

    public init(
        name: String,
        products: [Product],
        dependencies: [Dependency],
        targets: [Target]
    ) {
        self.name = name
        self.products = products
        self.dependencies = dependencies
        self.targets = targets
    }
}

extension Package {
    public struct Product {
        public var name: String
        public var targets: [String]

        public init(
            name: String,
            targets: [String]
        ) {
            self.name = name
            self.targets = targets
        }
    }

    public struct Dependency {
        public var identity: String
        public var location: Location

        public enum Location {
            case remote(URL)

            public var url: URL {
                switch self {
                case .remote(let url): return url
                }
            }
        }

        public init(
            identity: String,
            location: Location
        ) {
            self.identity = identity
            self.location = location
        }
    }

    public struct Target {
        public var name: String
        public var dependencies: [Dependency]

        public enum Dependency: Equatable {
            case target(name: String)
            case product(name: String, package: String?)
            case byName(String)
        }

        public init(
            name: String,
            dependencies: [Dependency]
        ) {
            self.name = name
            self.dependencies = dependencies
        }
    }
}
