import Foundation
import Logging

public struct LicenseGen {
    public enum Error: Swift.Error {
        case invalidPath(URL)
    }

    private let fileIO = DefaultFileIO()
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func run(with options: Options) throws {
        try Self.validateOptions(options, using: fileIO)

        let checkouts = try Self.findCheckoutContents(in: options.checkoutsPaths, using: fileIO)
        let licenses: [License]
        if !options.packagePaths.isEmpty {
            licenses = try options.packagePaths
                .flatMap { path in
                    try Self.collectLibraries(for: path, with: checkouts, logger: logger, using: fileIO)
                }
                .compactMap {
                    try Self.generateLicense(for: $0, logger: logger, using: fileIO)
                }
        } else {
            licenses = try checkouts.compactMap {
                try Self.generateLicense(for: $0, logger: logger, using: fileIO)
            }
        }

        let writer: OutputWriter = {
            switch options.outputFormat {
            case .settingsBundle(let prefix):
                return SettingsBundleWriter(prefix: prefix)
            }
        }()
        try writer.write(licenses.sorted(), to: options.outputPath, logger: logger, using: fileIO)

        logger.info("done!")
    }

    static func validateOptions(_ options: Options, using io: FileIO) throws {
        for path in options.checkoutsPaths + options.packagePaths {
            if !io.isDirectory(at: path) {
                throw Error.invalidPath(path)
            }
        }
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
                                 logger: Logger? = nil,
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
                            guard let checkout = checkouts[package.name.lowercased()] else {
                                if packages[rootPackagePath]?.targets.map(\.name).contains(name) ?? false {
                                    continue
                                }
                                logger?.warning("missing checkout: \(package.name)")
                                continue
                            }
                            libraries.append(.init(checkout: checkout, name: product.name))
                        }
                        try collectFromDependencies(for: name)

                    case .product(let name, let packageName):
                        let packageName = packageName ?? name
                        guard let checkout = checkouts[packageName.lowercased()] else {
                            logger?.warning("missing checkout: \(packageName)")
                            return
                        }

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

    static func generateLicense(for library: Library, logger: Logger? = nil, using io: FileIO) throws -> License? {
        let candidates = ["LICENSE", "LICENSE.md", "LICENSE.txt"]

        for c in candidates {
            let path = library.checkout.path.appendingPathComponent(c)
            guard io.isExists(at: path) else { continue }
            let content = try io.readContents(at: path)
            return License(source: library, name: library.name, content: .init(version: nil, body: content))
        }
        logger?.critical("""
        missing license: \(library.name), \
        location \(library.checkout.path)/[\(candidates.joined(separator: " | "))]
        """)
        return nil
    }
}
