import Foundation
import ArgumentParser
import Yams
import Logging
import LicenseGenKit

struct LicenseGenCommand: ParsableCommand {
    enum OutputFormat: String, EnumerableFlag {
        case settingsBundle

        static func help(for value: LicenseGenCommand.OutputFormat) -> ArgumentHelp? {
            switch value {
            case .settingsBundle:
                return "plist style for application"
            }
        }
    }

    @Option(name: .long,
            help: "You can specify config path. Default: .licensegen.yml")
    var configPath: String?

    @Option(name: .long,
            help: "You can specify custom spm checkouts path. Default: ${BUILD_DIR}/../../SourcePackages/checkouts",
            completion: .directory)
    var checkoutsPath: String?

    @Option(wrappedValue: [],
            name: .long,
            parsing: .upToNextOption,
            help: "Package.swift directory",
            completion: .directory)
    var packagePaths: [String]

    @Option(name: .long,
            help: "You can specify output directory, otherwise print stdout")
    var outputPath: String?

    @Flag
    var outputFormat: OutputFormat

    @Flag(help: "Generate licenses per package products")
    var perProducts: Bool = false

    @Option(name: .long,
            help: "You must specify prefix, when you set --settings-bundle")
    var settingsBundlePrefix: String?

    mutating func run() throws {
        if packagePaths.isEmpty && perProducts {
            throw ValidationError("You must specify --per-products with --package-paths")
        }
        let options = Options(checkoutsPaths: try extractCheckoutPaths(),
                              packagePaths: packagePaths.map(URL.init(fileURLWithPath:)),
                              outputPath: outputPath.map(URL.init(fileURLWithPath:)),
                              outputFormat: try extractOutputFormat(),
                              perProducts: perProducts,
                              config: try extractConfig())

        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "lisencegen")
        try LicenseGen(logger: logger).run(with: options)
    }

    private func extractConfig() throws -> Options.Config? {
        func extractConfigPath() -> String? {
            if configPath == nil {
                let path = ".licensegen.yml"
                if FileManager.default.fileExists(atPath: path) {
                    return path
                }
                return nil
            }
            return configPath
        }

        guard let configPath = extractConfigPath() else { return nil }
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
            guard case let configs = try YAMLDecoder().decode([String: Config].self, from: data),
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

    private func extractCheckoutPaths() throws -> [URL] {
        let checkoutsURL: URL
        if let checkoutsPath = checkoutsPath {
            checkoutsURL = URL(fileURLWithPath: checkoutsPath)
        } else if let dir = ProcessInfo.processInfo.environment["BUILD_DIR"] {
            checkoutsURL = URL(fileURLWithPath: dir)
                .appendingPathComponent("../")
                .appendingPathComponent("../")
                .appendingPathComponent("SourcePackages")
                .appendingPathComponent("checkouts")
        } else {
            throw ValidationError("missing BUILD_DIR")
        }
        return [checkoutsURL]
    }

    private func extractOutputFormat() throws -> Options.OutputFormat {
        switch outputFormat {
        case .settingsBundle:
            if let prefix = settingsBundlePrefix {
                return .settingsBundle(prefix: prefix)
            }
            throw ValidationError("Missing expected argument '--settings-bundle-prefix <settings-bundle-prefix>'")
        }
    }
}

extension LicenseGenCommand {
    struct Config {
        var ignore: Ignore
        var licensePath: String?

        struct Ignore {
            var value: Bool
        }
    }
}

extension LicenseGenCommand.Config: Decodable {
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

extension LicenseGenCommand.Config.Ignore: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = true
            return
        }
        value = try container.decode(Bool.self)
    }
}

LicenseGenCommand.main()
