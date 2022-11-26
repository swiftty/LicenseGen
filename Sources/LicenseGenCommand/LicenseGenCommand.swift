import Foundation
import ArgumentParser
import Logging
import LicenseGenKit

public struct LicenseGenCommand: ParsableCommand {
    @OptionGroup
    var options: CommandOptions

    public init() {}

    public mutating func run() throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "lisencegen")
        try LicenseGen(logger: logger).run(
            with: Options(checkoutsPaths: try options.validatedCheckoutsPaths().map(\.url),
                          packagePaths: options.packagePaths.map(\.url),
                          outputPath: options.outputPath?.url,
                          outputFormat: try options.validatedOutputFormat(),
                          perProducts: options.perProducts,
                          config: try options.config ?? .default())
        )
    }
}
