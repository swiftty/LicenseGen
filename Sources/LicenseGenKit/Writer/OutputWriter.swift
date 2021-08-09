import Foundation
import Logging

protocol OutputWriter {
    func write(_ licenses: [License], to outputPath: URL?, logger: Logger?, using io: FileIO) throws
}
