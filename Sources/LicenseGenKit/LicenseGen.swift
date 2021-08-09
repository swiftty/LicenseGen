import Foundation
import Logging

public struct LicenseGen {
    public enum Error: Swift.Error {
        case invalidPath(URL)
        case missingLicense(String)
    }

    private let fileIO = DefaultFileIO()
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func run(with options: Options) throws {
        try Self.validateOptions(options, using: fileIO)

        let checkouts = try Self.findCheckoutContents(in: options.checkoutsPaths, using: fileIO)
        let libraries: [Library]
        if !options.packagePaths.isEmpty {
            libraries = try options.packagePaths.flatMap { path in
                try Self.collectLibraries(for: path, with: checkouts, logger: logger, using: fileIO)
            }
        } else {
            libraries = checkouts
        }

        var modifiers = options.config?.modifiers
        let licenses = try libraries.compactMap {
            try Self.generateLicense(for: $0, modifiers: &modifiers, logger: logger, using: fileIO)
        }
        modifiers?.keys.forEach { key in
            logger.warning(#"Unused settings found: "\#(key)""#)
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

        func dumpPackage(path: URL, for specifiedProduct: String? = nil) throws {
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
                        if dep == .byName(name),
                           let checkout = checkouts[name.lowercased()],
                           packages[checkout.path] == nil {

                            libraries.append(.init(checkout: checkout, name: name))
                            try dumpPackage(path: checkout.path, for: name)
                            continue
                        }
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

                        try dumpPackage(path: checkout.path, for: name)
                    }
                }
            }

            for p in package.products where specifiedProduct.map({ $0 == p.name }) ?? true {
                for t in p.targets {
                    try collectFromDependencies(for: t)
                }
            }
        }

        try dumpPackage(path: rootPackagePath)
        return libraries.uniqued()
    }

    static func generateLicense(for library: Library,
                                modifiers: inout [String: Options.Config.Setting]?,
                                logger: Logger? = nil,
                                using io: FileIO) throws -> License? {
        let missingAsError: Bool
        let candidates: [String]
        defer { modifiers?[library.name] = nil }
        switch modifiers?[library.name] {
        case .ignore:
            return nil

        case .licensePath(let path):
            candidates = [path]
            missingAsError = true

        case nil:
            candidates = ["LICENSE", "LICENSE.md", "LICENSE.txt"]
            missingAsError = false
        }

        for c in candidates {
            let path = library.checkout.path.appendingPathComponent(c)
            guard io.isExists(at: path) else { continue }
            let content = try io.readContents(at: path)
            return License(source: library, name: library.name, content: .init(version: nil, body: content))
        }

        let candidateMessage = candidates.count > 1
            ? "(\(candidates.joined(separator: " | ")))"
            : "\(candidates.joined())"
        logger?.critical("""
        missing license: \(library.name), \
        location \(library.checkout.path)\(candidateMessage)
        """)

        if missingAsError {
            throw Error.missingLicense("\(library.checkout.path)\(candidateMessage)")
        }

        return nil
    }
}
