import Foundation
import Logging

public struct LicenseGen {
    public enum Error: Swift.Error {
        case invalidPath(URL)
        case missingLicense(String)
        case missingLibrary([String])

        case unknownSwiftPM(String)
    }

    private let fileIO = DefaultFileIO()
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func run(with options: Options) async throws {
        try Self.validateOptions(options, using: fileIO)

        let checkouts = try await Self.findCheckoutContents(in: options.checkoutsPaths, logger: logger, using: fileIO)
        var libraries: [Library]
        if !options.packagePaths.isEmpty {
            let packageDecoder = try PackageDecoder.from(fileIO.packageVersion())
            libraries = try await withThrowingTaskGroup(of: [Library].self) { group in
                for path in options.packagePaths {
                    group.addTask {
                        try await Self.collectLibraries(for: path, with: checkouts,
                                                        packageDecoder: packageDecoder, logger: logger, using: fileIO)
                    }
                }
                return try await group.reduce(into: []) {
                    $0.append(contentsOf: $1)
                }
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
                                     using io: FileIO) async throws -> [CheckoutContent] {
        return try await withThrowingTaskGroup(of: [CheckoutContent].self) { group -> [CheckoutContent] in
            for checkoutsPath in checkoutsPaths {
                group.addTask {
                    let contents = try logging(logger) {
                        try io.getDirectoryContents(at: checkoutsPath)
                    }
                    var checkouts: [CheckoutContent] = []
                    for path in contents where io.isDirectory(at: path) {
                        checkouts.append(.init(path: path))
                    }
                    return checkouts
                }
            }
            return try await group
                .reduce(into: []) { $0.append(contentsOf: $1) }
                .uniqued(by: \.name)
                .sorted()
        }
    }

    static func collectLibraries(for rootPackagePath: URL,
                                 with checkouts: [CheckoutContent],
                                 packageDecoder: PackageDecoder,
                                 logger: Logger? = nil,
                                 using io: FileIO) async throws -> [Library] {
        let checkouts = Dictionary(uniqueKeysWithValues: checkouts.map {
            ($0.name.lowercased(), $0)
        })

        struct PackageInfo {
            var description: PackageDescription
            var dirname: String
        }
        struct CheckKey: Hashable {
            var packageName: String
            var name: String
        }

        actor Collector {
            var packages: [URL: PackageInfo] = [:]
            var libraries: Set<SpecifiedLibrary> = []
            var collectedTargets: Set<CheckKey> = []
            var missingProducts: Set<String> = []

            func addPackage(_ package: PackageInfo, for path: URL) {
                packages[path] = package
            }

            func addLibrary(_ library: SpecifiedLibrary) {
                libraries.insert(library)
            }

            func collect(_ key: CheckKey) {
                collectedTargets.insert(key)
            }

            func addMissingProduct(_ target: String) {
                missingProducts.insert(target)
            }

            func removeMissingProduct(_ target: String) {
                missingProducts.remove(target)
            }
        }

        let collector = Collector()

        @Sendable
        func dumpPackage(path: URL, for specifiedProduct: String? = nil) async throws {
            let package: PackageInfo
            if let p = await collector.packages[path] {
                package = p
            } else {
                logger?.info("dump package \(path.lastPathComponent) with swiftpm")
                let data = try logging(logger) {
                    try io.dumpPackage(at: path)
                }
                let desc = try logging(logger) {
                    try packageDecoder.decode(from: data)
                }
                package = .init(description: desc, dirname: path.lastPathComponent)
                await collector.addPackage(package, for: path)
            }

            @Sendable
            func collectFromDependencies(for targetName: String) async throws {
                let key = CheckKey(packageName: package.description.name, name: targetName)
                if await collector.collectedTargets.contains(key) {
                    await collector.removeMissingProduct(targetName)
                    return
                }
                await collector.collect(key)
                guard let target = package.description.targets.first(where: { $0.name == targetName }) else {
                    return
                }
                await collector.removeMissingProduct(targetName)

                for dep in target.dependencies {
                    switch dep {
                    case .byName(let name), .target(let name):
                        if dep == .byName(name),
                           let checkout = checkouts[name.lowercased()],
                           await collector.packages[checkout.path] == nil {

                            await collector.addLibrary(.init(checkout: checkout, name: name))
                            try await dumpPackage(path: checkout.path, for: name)
                            continue
                        }
                        await collector.addMissingProduct(name)
                        for product in package.description.products where product.targets.contains(name) {
                            guard let checkout = checkouts[package.dirname.lowercased()] else {
                                let p = await collector.packages[rootPackagePath]
                                if p?.description.targets.map(\.name).contains(name) ?? false {
                                    continue
                                }
                                logger?.warning("missing checkout: \(package.description.name)")
                                continue
                            }
                            await collector.removeMissingProduct(name)
                            await collector.addLibrary(.init(checkout: checkout, name: product.name))
                        }
                        try await collectFromDependencies(for: name)

                    case .product(let name, let packageName):
                        let packageName = packageName ?? name
                        var dirname: String {
                            guard let dep = package.description.dependencies
                                    .first(where: { $0.name == packageName }) else { return packageName }
                            return dep.url.deletingPathExtension().lastPathComponent
                        }
                        guard let checkout = checkouts[dirname.lowercased()] else {
                            logger?.warning("missing checkout: \(packageName)")
                            return
                        }

                        await collector.removeMissingProduct(name)
                        await collector.addLibrary(.init(checkout: checkout, name: name))

                        try await dumpPackage(path: checkout.path, for: name)
                    }
                }
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for p in package.description.products where specifiedProduct.map({ $0 == p.name }) ?? true {
                    for t in p.targets {
                        group.addTask {
                            try await collectFromDependencies(for: t)
                        }
                    }
                }
                try await group.waitForAll()
            }
        }

        try await dumpPackage(path: rootPackagePath)

        for lib in await collector.libraries {
            await collector.removeMissingProduct(lib.name)
        }

        if await !collector.missingProducts.isEmpty {
            let libs = await collector.missingProducts.sorted()
            logger?.error("missing library found: \(libs.joined(separator: ", "))")
            throw Error.missingLibrary(libs)
        }
        return Array(await collector.libraries)
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
