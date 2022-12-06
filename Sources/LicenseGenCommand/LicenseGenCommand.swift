import Foundation
import ArgumentParser
import Logging
import LicenseGenKit
import LicenseGenEntity

public struct LicenseGenCommand: AsyncParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "licensegen"
        )
    }

    @OptionGroup
    var options: CommandOptions

    public init() {}

    public mutating func run() async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "lisencegen")
        try await TaskValues.$logger.withValue(logger) {
            try await LicenseGen().run(
                with: Options(checkoutsPaths: try options.validatedCheckoutsPaths().map(\.url),
                              packagePaths: options.packagePaths.map(\.url),
                              outputPath: options.outputPath?.url,
                              outputFormat: try options.validatedOutputFormat(),
                              perProducts: options.perProducts,
                              config: try options.config ?? .default())
            )
        }
    }
}
