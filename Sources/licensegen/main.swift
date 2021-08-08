import Foundation
import ArgumentParser
import LicenseGenKit

struct LicenseGenCommand: ParsableCommand {
    @Option(name: .long,
            help: "You can specify custom spm checkouts path. Default: ${BUILD_DIR}/../../SourcePackages/checkouts",
            completion: .directory)
    var checkoutsPath: String?

    @Option(wrappedValue: [],
            name: .long,
            parsing: .upToNextOption,
            help: "",
            completion: .file())
    var packagePaths: [String]

    mutating func run() throws {
        let options = Options(checkoutsPaths: try extractCheckoutPaths(),
                              packagePaths: packagePaths.map(URL.init(fileURLWithPath:)))
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
            throw ValidationError("missing BUILD_DIR")
        }
        return [checkoutsURL]
    }
}

LicenseGenCommand.main()
