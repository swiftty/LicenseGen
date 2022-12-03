import Foundation
import LicenseGenEntity

protocol OutputWriter {
    func write(_ licenses: [License], to outputPath: URL?, using io: FileIO) throws
}
