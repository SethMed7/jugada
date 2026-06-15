import Foundation

/// Turns a fetched JSON blob into a flat list of the numeric values inside it, each with the
/// dot-path that reaches it. This is what lets the "Add a watch" picker say "click the value
/// you want" instead of making someone type a path — the click maps straight to `path`.
///
/// Numeric only, on purpose: the engine watches numbers in this slice, so showing
/// non-numeric leaves would offer choices that can't yet be watched. Booleans are excluded
/// (they're `NSNumber` under the hood but aren't values you threshold).
enum JSONFlatten {
    struct Leaf {
        let path: String    // "bitcoin.usd" — what goes in Watcher.extract.path
        let label: String   // "bitcoin › usd" — human-friendly, for the picker row
        let value: Double
    }

    static func numericLeaves(from data: Data, limit: Int = 200) -> [Leaf] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var out: [Leaf] = []
        walk(root, path: [], into: &out, limit: limit)
        return out.sorted { $0.path < $1.path }   // stable order (dict iteration isn't)
    }

    private static func walk(_ node: Any, path: [String], into out: inout [Leaf], limit: Int) {
        guard out.count < limit else { return }
        if let dict = node as? [String: Any] {
            for (key, value) in dict { walk(value, path: path + [key], into: &out, limit: limit) }
        } else if let array = node as? [Any] {
            for (index, value) in array.enumerated() { walk(value, path: path + [String(index)], into: &out, limit: limit) }
        } else if let number = node as? NSNumber, !isBool(number) {
            out.append(Leaf(path: path.joined(separator: "."),
                            label: path.joined(separator: " › "),
                            value: number.doubleValue))
        } else if let string = node as? String, let value = Double(string) {
            out.append(Leaf(path: path.joined(separator: "."),
                            label: path.joined(separator: " › "),
                            value: value))
        }
    }

    private static func isBool(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
