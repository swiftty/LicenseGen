import Foundation

public struct License {
    public var source: any Library
    public var name: String
    public var content: Content

    public init(
        source: some Library,
        name: String,
        content: Content
    ) {
        self.source = source
        self.name = name
        self.content = content
    }

    public struct Content {
        public var version: String?  // TODO:
        public var body: String

        public init(
            version: String? = nil,
            body: String
        ) {
            self.version = version
            self.body = body
        }
    }
}

extension License: Equatable, Comparable {
    public static func < (lhs: License, rhs: License) -> Bool {
        return lhs.name < rhs.name
            || (lhs.content.version ?? "").compare(rhs.content.version ?? "", options: .numeric) == .orderedDescending
    }

    public static func == (lhs: License, rhs: License) -> Bool {
        return lhs.name == rhs.name
            && lhs.content.version == rhs.content.version
    }
}
