import Foundation
import Logging

protocol OutputWriter {
    func write(_ licenses: [License], to outputPath: URL?, using io: FileIO) throws
}
