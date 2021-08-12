import Foundation

public struct Options {
    public var checkoutsPaths: [URL]

    public var packagePaths: [URL]

    public var outputPath: URL?

    public var outputFormat: OutputFormat

    public var perProducts: Bool

    public var config: Config?

    public init(
        checkoutsPaths: [URL],
        packagePaths: [URL] = [],
        outputPath: URL?,
        outputFormat: OutputFormat,
        perProducts: Bool = false,
        config: Config? = nil
    ) {
        self.checkoutsPaths = checkoutsPaths
        self.packagePaths = packagePaths
        self.outputPath = outputPath
        self.outputFormat = outputFormat
        self.perProducts = perProducts
        self.config = config
    }
}

extension Options {
    public enum OutputFormat {
        case settingsBundle(prefix: String)
    }

    public struct Config {
        public var modifiers: [String: Setting]

        public enum Setting {
            case ignore
            case licensePath(String)
        }

        public init(
            modifiers: [String: Setting]
        ) {
            self.modifiers = modifiers
        }
    }
}
