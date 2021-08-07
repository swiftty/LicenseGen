import Foundation

extension Array {
    func uniqued<H: Hashable>(by target: (Element) -> H) -> [Element] {
        var set: Set<H> = []
        return filter { e in
            let key = target(e)
            defer { set.insert(key) }
            return !set.contains(key)
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        uniqued(by: { $0 })
    }
}
