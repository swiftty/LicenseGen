import Foundation
import ArgumentParser
import LicenseGenKit

struct LicenseGenCommand: ParsableCommand {
    enum OutputFormat: String, EnumerableFlag {
        case settingsBundle

        static func help(for value: LicenseGenCommand.OutputFormat) -> ArgumentHelp? {
            switch value {
            case .settingsBundle:
                return "plist style for iOS"
            }
        }
    }

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
                              outputFormat: try extractOutputFormat())
        try LicenseGen().run(with: options)
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

LicenseGenCommand.main()
