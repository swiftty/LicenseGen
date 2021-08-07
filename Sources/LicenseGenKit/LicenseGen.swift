import Foundation

public struct LicenseGen {
    public init() {}

    public func run(with options: Options) throws {
    }

    func findCheckoutContents(in checkoutsPaths: [URL],
                              using io: FileIO) throws -> [CheckoutContent] {
        var checkouts: [CheckoutContent] = []
        for checkoutsPath in checkoutsPaths {
            for path in try io.getDirectoryContents(at: checkoutsPath) {
                checkouts.append(.init(path: path))
            }
        }
        return checkouts.uniqued().sorted()
    }

    func collectLibraries(for rootPackagePath: URL,
                          with checkouts: [CheckoutContent],
                          using io: FileIO) throws -> [Library] {
        let checkouts = Dictionary(uniqueKeysWithValues: checkouts.map {
            ($0.name.lowercased(), $0)
        })

        var packages: [URL: PackageDescription] = [:]
        var libraries: [Library] = []

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
                        for product in package.products.filter({ $0.targets.contains(name) }) {
                            guard let checkout = checkouts[package.name.lowercased()] else { continue }
                            libraries.append(.init(checkout: checkout, name: product.name))
                        }
                        try collectFromDependencies(for: name)

                    case .product(let name, let packageName):
                        let packageName = packageName ?? name
                        guard let checkout = checkouts[packageName.lowercased()] else { return }

                        libraries.append(.init(checkout: checkout, name: name))

                        try dumpPackage(path: checkout.path.appendingPathComponent("Package.swift"),
                                        only: [name])
                    }
                }
            }

            for target in Set(package.products.flatMap(\.targets)) where onlyTargets?.contains(target) ?? true {
                try collectFromDependencies(for: target)
            }
        }

        try dumpPackage(path: rootPackagePath.appendingPathComponent("Package.swift"))
        return libraries.uniqued()
    }
}
