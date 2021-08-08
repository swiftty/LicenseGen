import Foundation

public struct LicenseGen {
    private let fileIO = DefaultFileIO()

    public init() {}

    public func run(with options: Options) throws {
        let checkouts = try Self.findCheckoutContents(in: options.checkoutsPaths, using: fileIO)
        let licenses: [License]
        if !options.packagePaths.isEmpty {
            licenses = try options.packagePaths
                .flatMap { path in
                    try Self.collectLibraries(for: path, with: checkouts, using: fileIO)
                }
                .map {
                    try Self.generateLicense(for: $0, using: fileIO)
                }
        } else {
            licenses = try checkouts.map {
                try Self.generateLicense(for: $0, using: fileIO)
            }
        }
        print(licenses.sorted().map {
            ($0.name,
             $0.content?.body.prefix(20))
        })
    }

    static func findCheckoutContents(in checkoutsPaths: [URL],
                                     using io: FileIO) throws -> [CheckoutContent] {
        var checkouts: [CheckoutContent] = []
        for checkoutsPath in checkoutsPaths {
            for path in try io.getDirectoryContents(at: checkoutsPath) where io.isDirectory(at: path) {
                checkouts.append(.init(path: path))
            }
        }
        return checkouts.uniqued(by: \.name).sorted()
    }

    static func collectLibraries(for rootPackagePath: URL,
                                 with checkouts: [CheckoutContent],
                                 using io: FileIO) throws -> [Library] {
        let checkouts = Dictionary(uniqueKeysWithValues: checkouts.map {
            ($0.name.lowercased(), $0)
        })

        var packages: [URL: PackageDescription] = [:]
        var libraries: [SpecifiedLibrary] = []

        func dumpPackage(path: URL, only onlyTargets: Set<String>? = nil) throws {
            let package: PackageDescription
            if let p = packages[path] {
                package = p
            } else {
                let data = try io.dumpPackage(at: path)
                package = try JSONDecoder().decode(PackageDescription.self, from: data)
                packages[path] = package
            }

            func collectFromDependencies(for targetName: String) throws {
                guard let target = package.targets.first(where: { $0.name == targetName }) else {
                    return
                }

                for dep in target.dependencies {
                    switch dep {
                    case .byName(let name), .target(let name):
                        for product in package.products where product.targets.contains(name) {
                            guard let checkout = checkouts[package.name.lowercased()] else { continue }
                            libraries.append(.init(checkout: checkout, name: product.name))
                        }
                        try collectFromDependencies(for: name)

                    case .product(let name, let packageName):
                        let packageName = packageName ?? name
                        guard let checkout = checkouts[packageName.lowercased()] else { return }

                        libraries.append(.init(checkout: checkout, name: name))

                        try dumpPackage(path: checkout.path, only: [name])
                    }
                }
            }

            for target in Set(package.products.flatMap(\.targets)) where onlyTargets?.contains(target) ?? true {
                try collectFromDependencies(for: target)
            }
        }

        try dumpPackage(path: rootPackagePath)
        return libraries.uniqued()
    }

    static func generateLicense(for library: Library, using io: FileIO) throws -> License {
        let candidates = ["LICENSE", "LICENSE.md", "LICENSE.txt"]

        for c in candidates {
            let path = library.checkout.path.appendingPathComponent(c)
            guard io.isExists(at: path) else { continue }
            let content = try io.readContents(at: path)
            return License(source: library, name: library.name, content: .init(version: nil, body: content))
        }
        return License(source: library, name: library.name, content: nil)
    }
}
