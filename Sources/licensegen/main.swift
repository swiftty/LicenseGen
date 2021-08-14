import Foundation
import ArgumentParser
import Yams
import Logging
import LicenseGenKit

struct LicenseGenCommand: ParsableCommand {
    @OptionGroup
    var options: CommandOptions

    mutating func run() throws {
        let options = Options(checkoutsPaths: options.checkoutsPaths.isEmpty
                                ? options.checkoutsPaths.map(\.url)
                                : [try CommandOptions.CheckoutPath.default().url],
                              packagePaths: options.packagePaths.map(\.url),
                              outputPath: options.outputPath?.url,
                              outputFormat: try options.outputFormat(),
                              perProducts: options.perProducts,
                              config: try options.config ?? .default())

        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "lisencegen")
        try LicenseGen(logger: logger).run(with: options)
    }
}

LicenseGenCommand.main()
