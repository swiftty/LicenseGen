import Foundation
import ArgumentParser
import Yams
import LicenseGenKit

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
    var checkoutsPaths: [CheckoutPath] = []

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

extension CommandOptions {
    struct Config {
        var ignore: Ignore
        var licensePath: String?

        struct Ignore {
            var value: Bool
        }
    }
}

extension CommandOptions.Config: Decodable {
    private enum CodingKeys: String, CodingKey {
        case ignore
        case licensePath = "license_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            ignore = try container.decode(Ignore.self, forKey: .ignore)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "ignore" {
            ignore = Ignore(value: false)
        }
        licensePath = try container.decodeIfPresent(String.self, forKey: .licensePath)
    }
}

extension CommandOptions.Config.Ignore: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = true
            return
        }
        value = try container.decode(Bool.self)
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
            throw ValidationError("missing BUILD_DIR")
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
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return try load(from: path)
    }

    fileprivate static func transform(from configPath: String) throws -> Self? {
        try load(from: configPath)
    }

    private static func load(from configPath: String) throws -> Self? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: configPath, isDirectory: &isDirectory) else {
            throw ValidationError("invalid --config-path \(configPath)")
        }
        var filePath = URL(fileURLWithPath: configPath)
        if isDirectory.boolValue {
            filePath.appendPathComponent(".licensegen.yml")
        }

        let data: Data
        do {
            data = try Data(contentsOf: filePath)
        } catch {
            throw ValidationError("missing \(filePath.path)")
        }

        do {
            guard case let configs = try YAMLDecoder().decode([String: CommandOptions.Config].self, from: data),
                  !configs.isEmpty else { return nil }

            return try Options.Config(modifiers: configs.compactMapValues {
                if $0.ignore.value && $0.licensePath != nil {
                    throw ValidationError("You can only specify ignore: or license_path:")
                }
                if $0.ignore.value {
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
            throw ValidationError("cannot parse \(filePath.lastPathComponent). \(error)")
        }
    }
}
