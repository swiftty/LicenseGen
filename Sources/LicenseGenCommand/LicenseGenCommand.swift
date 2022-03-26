import Foundation
import ArgumentParser
import Logging
import LicenseGenKit

public struct LicenseGenCommand: AsyncParsableCommand {
    @OptionGroup
    var options: CommandOptions

    public init() {}

    public mutating func run() async throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        let logger = Logger(label: "lisencegen")
        try await LicenseGen(logger: logger).run(
            with: Options(checkoutsPaths: try options.checkoutsPaths().map(\.url),
                          packagePaths: options.packagePaths.map(\.url),
                          outputPath: options.outputPath?.url,
                          outputFormat: try options.outputFormat(),
                          perProducts: options.perProducts,
                          config: try options.config ?? .default())
        )
    }
}
