import Yams

/// One pack item as written, after merges: `Kind id` and its mapping.
struct RawItem {
    var key: String
    var node: Node
}

/// Compares the content of two revisions of the game data, item by item,
/// after anchors and merge keys are resolved. Formatting, comments, key
/// order and which pack an item lives in are not changes.
public enum ContentDiff {
    /// One line per changed value, `Kind id: field old → new`, then
    /// `added Kind id` and `removed Kind id` lines. Changed and added items
    /// follow the new revision's load order, removed ones the old one's.
    public static func diff(old: PackSource, new: PackSource) -> Result<[String], GameDataErrors> {
        GameDataLoader.items(from: old).flatMap { oldItems in
            GameDataLoader.items(from: new).map { newItems in
                lines(old: oldItems, new: newItems)
            }
        }
    }

    private static func lines(old: [RawItem], new: [RawItem]) -> [String] {
        let before = Dictionary(old.map { ($0.key, values(of: $0.node)) }) { first, _ in first }
        let afterKeys = Set(new.map(\.key))
        var lines: [String] = []
        var seen = Set<String>()
        for item in new where seen.insert(item.key).inserted {
            guard let previous = before[item.key] else {
                lines.append("added \(item.key)")
                continue
            }
            let current = values(of: item.node)
            let was = Dictionary(previous.map { ($0.path, $0.value) }) { first, _ in first }
            let now = Dictionary(current.map { ($0.path, $0.value) }) { first, _ in first }
            let fields = current.map(\.path) + previous.map(\.path).filter { now[$0] == nil }
            for field in fields {
                let was = was[field], now = now[field]
                if was != now {
                    lines.append("\(item.key): \(field) \(was ?? "(none)") → \(now ?? "(none)")")
                }
            }
        }
        var removed = Set<String>()
        for item in old where !afterKeys.contains(item.key) && removed.insert(item.key).inserted {
            lines.append("removed \(item.key)")
        }
        return lines
    }

    /// The item's leaf values keyed by dotted path, in the order written.
    /// A list of scalars is one value, so `[2, 3]` compares as a whole.
    private static func values(of item: Node) -> [(path: String, value: String)] {
        var values: [(path: String, value: String)] = []
        func walk(_ node: Node, _ path: String) {
            switch node {
            case let .mapping(mapping):
                for (key, value) in mapping {
                    let name = key.string ?? "\(key)"
                    if path.isEmpty, name == "kind" || name == "id" { continue }
                    walk(value, path.isEmpty ? name : "\(path).\(name)")
                }
            case let .sequence(sequence):
                let scalars = sequence.compactMap(\.string)
                if scalars.count == sequence.count {
                    values.append((path, "[" + scalars.joined(separator: ", ") + "]"))
                } else {
                    for (index, element) in sequence.enumerated() {
                        walk(element, "\(path)[\(index)]")
                    }
                }
            case let .scalar(scalar):
                values.append((path, scalar.string))
            case .alias:
                values.append((path, "\(node)"))
            }
        }
        walk(item, "")
        return values
    }
}
