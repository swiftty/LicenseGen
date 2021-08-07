import Foundation
import ArgumentParser
import LicenseGenKit

struct RuntimeError: Error, CustomStringConvertible {
    var description: String
}

struct LicenseGenCommand: ParsableCommand {
    @Option(name: .long,
            help: "You can specify custom spm checkouts path. Default: ${BUILD_DIR}/../../SourcePackages/checkouts",
            completion: .directory)
    var checkoutsPath: String?

    mutating func run() throws {
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
            throw RuntimeError(description: """
            missing BUILD_DIR
            """)
        }
        let options = Options(checkoutsPath: checkoutsURL)
        try LicenseGen().run(with: options)
    }
}

LicenseGenCommand.main()
