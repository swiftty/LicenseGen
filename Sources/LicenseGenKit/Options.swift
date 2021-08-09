import Foundation

public struct Options {
    public var checkoutsPaths: [URL]

    public var packagePaths: [URL]

    public var outputPath: URL?

    public var outputFormat: OutputFormat

    public init(
        checkoutsPaths: [URL],
        packagePaths: [URL] = [],
        outputPath: URL?,
        outputFormat: OutputFormat
    ) {
        self.checkoutsPaths = checkoutsPaths
        self.packagePaths = packagePaths
        self.outputPath = outputPath
        self.outputFormat = outputFormat
    }
}

extension Options {
    public enum OutputFormat {
        case settingsBundle(prefix: String)
    }
}
