import Foundation

struct License {
    var source: Library
    var name: String
    var content: Content

    struct Content {
        var version: String?  // TODO:
        var body: String
    }
}

extension License: Equatable, Comparable {
    static func < (lhs: License, rhs: License) -> Bool {
        lhs.name < rhs.name
            || (lhs.content.version ?? "")
            .compare(rhs.content.version ?? "", options: .numeric) == .orderedDescending
    }

    static func == (lhs: License, rhs: License) -> Bool {
        lhs.name == rhs.name && lhs.content.version == rhs.content.version
    }
}
