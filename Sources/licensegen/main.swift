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
            completion: .file())
    var packagePaths: [String]

    @Option(name: .long,
            help: "You can specify output directory, otherwise print stdout")
    var outputPath: String?

    @Flag
    var outputFormat: OutputFormat

    @Option(name: .long,
            help: "You must specify prefix, when you set --settings-bundle")
    var settingsBundlePrefix: String?

    mutating func run() throws {
        let options = Options(checkoutsPaths: try extractCheckoutPaths(),
                              packagePaths: packagePaths.map(URL.init(fileURLWithPath:)),
                              outputPath: outputPath.map(URL.init(fileURLWithPath:)),
                              outputFormat: try extractOutputFormat(),
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
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
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
            throw ValidationError("Missing BUILD_DIR")
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
    struct Config: Decodable {
        var ignore: Ignore
        var licensePath: String?

        private enum CodingKeys: String, CodingKey {
            case ignore
            case licensePath = "license_path"
        }

        struct Ignore: Decodable {
            var value: Bool
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if container.decodeNil() {
                    value = true
                    return
                }
                value = try container.decode(Bool.self)
            }
        }
    }
}

LicenseGenCommand.main()
