import Foundation

protocol OutputWriter {
    func write(_ licenses: [License], to outputPath: URL?) throws
}
