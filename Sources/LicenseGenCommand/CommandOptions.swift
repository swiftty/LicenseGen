import Foundation
import ArgumentParser
import Yams
import LicenseGenKit

var fileIO: FileIO = defaultFileIO()

struct CommandOptions: ParsableArguments {
    struct CheckoutPath {
        var url: URL
    }
    struct PackagePath {
        var url: URL
    }
    struct OutputPath {
        var url: URL
    }
    enum OutputFormat: String, EnumerableFlag {
        case settingsBundle

        static func help(for value: OutputFormat) -> ArgumentHelp? {
            switch value {
            case .settingsBundle:
                return "plist style for application"
            }
        }
    }

    @Option(name: .customLong("config-path"),
            help: "You can specify config path. Default: .licensegen.yml",
            transform: Options.Config.transform)
    var config: Options.Config?

    @Option(name: .customLong("checkouts-path"),
            help: "You can specify custom spm checkouts path. Default: ${BUILD_DIR}/../../SourcePackages/checkouts",
            completion: .directory,
            transform: CheckoutPath.transform)
    var _checkoutsPaths: [CheckoutPath] = []
    func checkoutsPaths() throws -> [CheckoutPath] {
        if _checkoutsPaths.isEmpty {
            return try [.default()]
        } else {
            return _checkoutsPaths
        }
    }

    @Option(name: .long,
            parsing: .upToNextOption,
            help: "Package.swift directory",
            completion: .directory,
            transform: PackagePath.transform)
    var packagePaths: [PackagePath] = []

    @Option(name: .long,
            help: "You can specify output directory, otherwise print stdout",
            transform: OutputPath.transform)
    var outputPath: OutputPath?

    @Flag(help: "Generate licenses per package products")
    var perProducts: Bool = false

    @Flag
    private var _outputFormat: OutputFormat

    @Option(name: .long,
            help: "You must specify prefix, when you set --settings-bundle")
    var settingsBundlePrefix: String?

    func validate() throws {
        if packagePaths.isEmpty && perProducts {
            throw ValidationError("You must specify --per-products with --package-paths")
        }
        _ = try outputFormat()
    }

    func outputFormat() throws -> Options.OutputFormat {
        switch _outputFormat {
        case .settingsBundle:
            guard let prefix = settingsBundlePrefix else {
                throw ValidationError("Missing expected argument '--settings-bundle-prefix <settings-bundle-prefix>'")
            }
            return .settingsBundle(prefix: prefix)
        }
    }
}

extension CommandOptions.CheckoutPath {
    static func `default`() throws -> Self {
        if let dir = ProcessInfo.processInfo.environment["BUILD_DIR"] {
            return Self.init(url: URL(fileURLWithPath: dir)
                                .appendingPathComponent("../")
                                .appendingPathComponent("../")
                                .appendingPathComponent("SourcePackages")
                                .appendingPathComponent("checkouts"))
        } else {
            throw ValidationError("BUILD_DIR not found")
        }
    }

    static func transform(from value: String) throws -> Self {
        Self.init(url: URL(fileURLWithPath: value))
    }
}

extension CommandOptions.PackagePath {
    static func transform(from value: String) throws -> Self {
        Self.init(url: URL(fileURLWithPath: value))
    }
}

extension CommandOptions.OutputPath {
    static func transform(from value: String) throws -> Self {
        Self.init(url: URL(fileURLWithPath: value))
    }
}

extension Options.Config {
    static func `default`() throws -> Self? {
        let path = ".licensegen.yml"
        guard fileIO.isExists(at: URL(fileURLWithPath: path)) else {
            return nil
        }
        return try load(from: path)
    }

    fileprivate static func transform(from configPath: String) throws -> Self? {
        try load(from: configPath)
    }

    private static func load(from configPath: String) throws -> Self? {
        var filePath = URL(fileURLWithPath: configPath)
        guard fileIO.isExists(at: filePath) else {
            throw ValidationError("Invalid --config-path \(configPath)")
        }
        if fileIO.isDirectory(at: filePath) {
            filePath.appendPathComponent(".licensegen.yml")
        }

        let data: Data
        do {
            let content = try fileIO.readContents(at: filePath)
            data = Data(content.utf8)
        } catch {
            throw ValidationError("Missing \(filePath.path)")
        }

        do {
            guard case let configs = try YAMLDecoder().decode([String: Content].self, from: data),
                  !configs.isEmpty else { return nil }

            return try Options.Config(modifiers: configs.compactMapValues {
                if $0.ignore && $0.licensePath != nil {
                    throw ValidationError("You can only specify ignore: or license_path:")
                }
                if $0.ignore {
                    return .ignore
                } else if let path = $0.licensePath {
                    return .licensePath(path)
                } else {
                    return nil
                }
            })
        } catch let error as ValidationError {
            throw error
        } catch {
            throw ValidationError("Cannot parse \(filePath.lastPathComponent). \(error)")
        }
    }

    private struct Content: Decodable {
        var ignore: Bool
        var licensePath: String?

        private enum CodingKeys: String, CodingKey {
            case ignore
            case licensePath = "license_path"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            licensePath = try container.decodeIfPresent(String.self, forKey: .licensePath)
            do {
                if try container.decodeNil(forKey: .ignore) {
                    ignore = true
                } else {
                    ignore = try container.decode(Bool.self, forKey: .ignore)
                }
            } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "ignore" {
                ignore = false
            }
        }
    }
}
