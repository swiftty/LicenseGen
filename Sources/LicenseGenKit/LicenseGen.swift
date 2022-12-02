import Foundation
import Logging
import LicenseGenEntity
import LicenseGenSwiftPMProxy

public struct LicenseGen {
    public enum Error: Swift.Error {
        case invalidPath(URL)
        case missingLicense(String)
        case missingLibrary([String])

        case unknownSwiftPM(String)
    }

    private let fileIO = DefaultFileIO()
    private let processIO: any ProcessIO = LicenseGenSwiftPMProxy.processIO
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func run(with options: Options) async throws {
        try Self.validateOptions(options, using: fileIO)

        let checkouts = try Self.findCheckoutContents(in: options.checkoutsPaths, logger: logger, using: fileIO)
        var libraries: [Library]
        if !options.packagePaths.isEmpty {
            let version = try await GetVersion().send(using: processIO)
            libraries = []
            for path in options.packagePaths {
                let libs = try await Self.collectLibraries(for: path, spmVersion: version, with: checkouts, using: processIO)
                libraries.append(contentsOf: libs)
            }
            if !options.perProducts {
                libraries = libraries.map(\.checkout).uniqued()
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
        for path in options.checkoutsPaths {
            if !io.isDirectory(at: path) {
                throw Error.invalidPath(path)
            }
        }
    }

    static func findCheckoutContents(in checkoutsPaths: [URL],
                                     logger: Logger?,
                                     using io: FileIO) throws -> [CheckoutContent] {
        var checkouts: [CheckoutContent] = []
        for checkoutsPath in checkoutsPaths {
            let contents = try logging(logger) {
                try io.getDirectoryContents(at: checkoutsPath)
            }
            for path in contents where io.isDirectory(at: path) {
                checkouts.append(.init(path: path))
            }
        }
        return checkouts.uniqued(by: \.name).sorted()
    }

    static func collectLibraries(for rootPackagePath: URL,
                                 spmVersion: String,
                                 with checkouts: [CheckoutContent],
                                 logger: Logger? = nil,
                                 using io: ProcessIO) async throws -> [Library] {
        let checkouts = Dictionary(uniqueKeysWithValues: checkouts.map {
            ($0.name.lowercased(), $0)
        })

        struct PackageInfo {
            var description: LicenseGenEntity.Package
            var dirname: String
        }
        struct CheckKey: Hashable {
            var packageName: String
            var name: String
        }

        var packages: [URL: PackageInfo] = [:]
        var libraries: Set<SpecifiedLibrary> = []
        var collectedTargets: Set<CheckKey> = []
        var missingProducts: Set<String> = []

        func dumpPackage(path: URL, for specifiedProduct: String? = nil) async throws {
            let package: PackageInfo
            if let p = packages[path] {
                package = p
            } else {
                let p = try await DumpPackage(path: path, spmVersion: spmVersion).send(using: io)
                package = .init(description: p, dirname: path.lastPathComponent)
                packages[path] = package
            }

            func collectFromDependencies(for targetName: String) async throws {
                let key = CheckKey(packageName: package.description.name, name: targetName)
                if collectedTargets.contains(key) {
                    missingProducts.remove(targetName)
                    return
                }
                collectedTargets.insert(key)
                guard let target = package.description.targets.first(where: { $0.name == targetName }) else {
                    return
                }
                missingProducts.remove(targetName)

                for dep in target.dependencies {
                    switch dep {
                    case .byName(let name), .target(let name):
                        if dep == .byName(name),
                           let checkout = checkouts[name.lowercased()],
                           packages[checkout.path] == nil {

                            libraries.insert(.init(checkout: checkout, name: name))
                            try await dumpPackage(path: checkout.path, for: name)
                            continue
                        }
                        missingProducts.insert(name)
                        for product in package.description.products where product.targets.contains(name) {
                            guard let checkout = checkouts[package.dirname.lowercased()] else {
                                if packages[rootPackagePath]?.description.targets.map(\.name).contains(name) ?? false {
                                    continue
                                }
                                logger?.warning("missing checkout: \(package.description.name)")
                                continue
                            }
                            missingProducts.remove(name)
                            libraries.insert(.init(checkout: checkout, name: product.name))
                        }
                        try await collectFromDependencies(for: name)

                    case .product(let name, let packageName):
                        let packageName = packageName ?? name
                        var dirname: String {
                            guard let dep = package.description.dependencies
                                    .first(where: { $0.identity == packageName }) else { return packageName }
                            return dep.location.url.deletingPathExtension().lastPathComponent
                        }
                        guard let checkout = checkouts[dirname.lowercased()] else {
                            logger?.warning("missing checkout: \(packageName)")
                            return
                        }

                        missingProducts.remove(name)
                        libraries.insert(.init(checkout: checkout, name: name))

                        try await dumpPackage(path: checkout.path, for: name)
                    }
                }
            }

            for p in package.description.products where specifiedProduct.map({ $0 == p.name }) ?? true {
                for t in p.targets {
                    try await collectFromDependencies(for: t)
                }
            }
        }

        try await dumpPackage(path: rootPackagePath)

        for lib in libraries {
            missingProducts.remove(lib.name)
        }

        if !missingProducts.isEmpty {
            let libs = missingProducts.sorted()
            logger?.error("missing library found: \(libs.joined(separator: ", "))")
            throw Error.missingLibrary(libs)
        }
        return Array(libraries)
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
            let content = try logging(logger) {
                try io.readContents(at: path)
            }
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

func logging<T>(_ logger: Logger?, message: @autoclosure () -> String? = nil,
                function: StaticString = #function, line: UInt = #line,
                _ closure: () throws -> T) rethrows -> T {
    do {
        return try closure()
    } catch let e {
        logger?.critical("\(message() ?? "Unexpected error")[\(function)L:\(line)]")
        throw e
    }
}
