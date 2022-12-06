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

    public init() {}

    public func run(with options: Options) async throws {
        try Self.validateOptions(options, using: fileIO)

        let checkouts = try Self.findCheckoutContents(in: options.checkoutsPaths, using: fileIO)
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
            try Self.generateLicense(for: $0, modifiers: &modifiers, using: fileIO)
        }
        modifiers?.keys.forEach { key in
            TaskValues.logger?.warning(#"Unused settings found: "\#(key)""#)
        }

        let writer: OutputWriter = {
            switch options.outputFormat {
            case .settingsBundle(let prefix):
                return SettingsBundleWriter(prefix: prefix)
            }
        }()
        try writer.write(licenses.sorted(), to: options.outputPath, using: fileIO)

        TaskValues.logger?.info("done!")
    }

    static func validateOptions(_ options: Options, using io: FileIO) throws {
        for path in options.checkoutsPaths {
            if !io.isDirectory(at: path) {
                throw Error.invalidPath(path)
            }
        }
    }

    static func findCheckoutContents(in checkoutsPaths: [URL],
                                     using io: FileIO) throws -> [Checkout] {
        var checkouts: [Checkout] = []
        for checkoutsPath in checkoutsPaths {
            let contents = try logging {
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
                                 with checkouts: [Checkout],
                                 using io: ProcessIO) async throws -> [Library] {
        let collector = LibraryCollector(checkouts: checkouts, spmVersion: spmVersion, using: io)
        try await collector.collect(at: rootPackagePath)
        let libraries = await collector.libraries
        return Array(libraries)
    }

    static func generateLicense(for library: Library,
                                modifiers: inout [String: Options.Config.Setting]?,
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
            let content = try logging {
                try io.readContents(at: path)
            }
            return License(source: library, name: library.name, content: .init(version: nil, body: content))
        }

        let candidateMessage = candidates.count > 1
            ? "(\(candidates.joined(separator: " | ")))"
            : "\(candidates.joined())"

        TaskValues.logger?.critical("""
        missing license: \(library.name), \
        location \(library.checkout.path)\(candidateMessage)
        """)

        if missingAsError {
            throw Error.missingLicense("\(library.checkout.path)\(candidateMessage)")
        }

        return nil
    }
}

// MARK: -
actor LibraryCollector {
    var libraries: Set<SpecifiedLibrary> = []
    private var packages: [URL: Package] = [:]
    private var collectedTargets: Set<TargetKey> = []
    private var unresolvedProducts: Set<String> = []

    private struct TargetKey: Hashable {
        var target: String
        var package: String
    }

    let checkouts: [String: Checkout]
    let spmVersion: String
    let io: ProcessIO

    init(checkouts: [Checkout], spmVersion: String, using io: ProcessIO) {
        self.checkouts = .init(uniqueKeysWithValues: checkouts.map { ($0.path.lastPathComponent.lowercased(), $0) })
        self.spmVersion = spmVersion
        self.io = io
    }

    func collect(at path: URL, only targetName: String? = nil) async throws {
        let package: Package
        if let p = packages[path] {
            package = p
        } else {
            TaskValues.logger?.info("dump package \(path.lastPathComponent) with swiftpm")

            package = try await DumpPackage(path: path, spmVersion: spmVersion).send(using: io)
            packages[path] = package
        }

        if let targetName, collectedTargets.contains(.init(target: targetName, package: package.name)) {
            return
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for product in package.products {
                let allTargets = Dictionary(uniqueKeysWithValues: package.targets.map { ($0.name, $0) })

                var targetNames = Set(
                    allTargets.keys.lazy
                        .filter { $0 == (targetName ?? $0) }
                        .filter { product.targets.contains($0) }
                )
                while let targetName = targetNames.popFirst(), let target = allTargets[targetName] {
                    if collectedTargets.contains(.init(target: targetName, package: package.name)) {
                        continue
                    }
                    collectedTargets.insert(.init(target: target.name, package: package.name))
                    for dep in target.dependencies {
                        switch dep {
                        case .byName(let name):
                            let checkout: Checkout
                            if let c = checkouts[name.lowercased()] {
                                checkout = c
                            } else {
                                targetNames.insert(name)
                                continue
                            }
                            libraries.insert(.init(checkout: checkout, name: name))

                            group.addTask {
                                try await self.collect(at: checkout.path, only: name)
                            }

                        case .target(let name):
                            targetNames.insert(name)

                        case .product(let name, let identity):
                            guard let identity, let checkout = checkouts[identity] else {
                                continue
                            }
                            libraries.insert(.init(checkout: checkout, name: name))
                            group.addTask {
                                try await self.collect(at: checkout.path, only: name)
                            }
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }
}
