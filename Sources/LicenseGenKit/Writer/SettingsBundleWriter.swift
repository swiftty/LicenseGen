import Foundation
import LicenseGenEntity

struct SettingsBundleWriter: OutputWriter {
    private let prefix: String

    init(prefix: String) {
        self.prefix = prefix
    }

    func write(_ licenses: [License], to outputPath: URL?, using io: FileIO) throws {
        let index = try encodeIndexPlist(with: licenses)
        let children = try licenses.map {
            ($0.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0.name,
             try encodeLicensePlist(for: $0))
        }

        if let outputPath = outputPath {
            if io.isExists(at: outputPath) && !io.isDirectory(at: outputPath) {
                throw LicenseGen.Error.invalidPath(outputPath)
            }

            func indexFile(in base: URL) -> URL {
                base.appendingPathComponent("\(prefix).plist")
            }
            func childDirectory(in base: URL) -> URL {
                base.appendingPathComponent(prefix)
            }
            func childFile(for key: String, in base: URL) -> URL {
                childDirectory(in: base).appendingPathComponent("\(key).plist")
            }

            TaskValues.logger?.info("creating... \(prefix).plist")
            let tmp = try io.createTmpDirectory()
            try io.writeContents(index, to: indexFile(in: tmp))

            try io.createDirectory(at: childDirectory(in: tmp))

            for (key, child) in children {
                TaskValues.logger?.info("creating... \(prefix)/\(key).plist")
                try io.writeContents(child, to: childFile(for: key, in: tmp))
            }

            if io.isExists(at: outputPath) {
                TaskValues.logger?.info("removing... current \(prefix)")
                if case let path = indexFile(in: outputPath), io.isExists(at: path) {
                    try io.remove(at: path)
                }
                if case let path = childDirectory(in: outputPath), io.isExists(at: path) {
                    try io.remove(at: path)
                }
            } else {
                TaskValues.logger?.info("creating... \(outputPath.lastPathComponent)")
                try io.createDirectory(at: outputPath)
            }

            TaskValues.logger?.info("finalizing...")
            try io.move(indexFile(in: tmp), to: indexFile(in: outputPath))
            try io.move(childDirectory(in: tmp), to: childDirectory(in: outputPath))

            do {
                try io.remove(at: tmp)
            } catch {
                TaskValues.logger?.warning("removing tmp directory. reason: \(error)")
            }
        } else {
            TaskValues.logger?.info("/// \(prefix).plist")
            print(String(data: index, encoding: .utf8) ?? "")
            for (key, child) in children {
                TaskValues.logger?.info("/// \(prefix)/\(key).plist")
                print(String(data: child, encoding: .utf8) ?? "")
            }
        }
    }

    private func encodeIndexPlist(with licenses: [License]) throws -> Data {
        let item = [
            "PreferenceSpecifiers": [
                IndexItem(title: "Licenses", type: .group)
            ] + licenses.map {
                IndexItem(file: "\(prefix)/\($0.name)", title: $0.name, type: .child)
            }
        ]

        let encoder = PropertyListEncoder.XMLEncoder()
        return try encoder.encode(item)
    }

    private func encodeLicensePlist(for license: License) throws -> Data {
        let item = [
            "PreferenceSpecifiers": [
                LicenseItem(footerText: license.content.body, type: .group)
            ]
        ]

        let encoder = PropertyListEncoder.XMLEncoder()
        return try encoder.encode(item)
    }
}

extension PropertyListEncoder {
    static func XMLEncoder() -> PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return encoder
    }
}

private enum TypeSpecifier: String, Encodable {
    case group = "PSGroupSpecifier"
    case child = "PSChildPaneSpecifier"
}

private struct IndexItem: Encodable {
    var file: String?
    var title: String
    var type: TypeSpecifier

    private enum CodingKeys: String, CodingKey {
        case file = "File"
        case title = "Title"
        case type = "Type"
    }
}

private struct LicenseItem: Encodable {
    var footerText: String
    var type: TypeSpecifier

    private enum CodingKeys: String, CodingKey {
        case footerText = "FooterText"
        case type = "Type"
    }
}
