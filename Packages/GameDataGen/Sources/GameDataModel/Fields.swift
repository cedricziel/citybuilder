import Yams

/// Resolves `<<` merge keys bottom-up. Keys written on the mapping win
/// over merged ones; among several merge sources the first one wins.
/// A source that is not a mapping is reported through `invalid`.
func resolvingMerges(_ node: Node, invalid: (Node) -> Void) -> Node {
    func resolve(_ node: Node) -> Node {
        resolvingMerges(node, invalid: invalid)
    }
    switch node {
    case let .mapping(mapping):
        var merged: [(Node, Node)] = []
        var explicit: [(Node, Node)] = []
        for (key, value) in mapping {
            guard let scalar = key.scalar, scalar.string == "<<", scalar.style == .plain else {
                explicit.append((key, resolve(value)))
                continue
            }
            let sources = value.sequence.map(Array.init) ?? [value]
            for source in sources.map(resolve) {
                guard case let .mapping(mapping) = source else {
                    invalid(source)
                    continue
                }
                merged += mapping.map { ($0.key, $0.value) }
            }
        }
        var seen = Set(explicit.compactMap { $0.0.scalar?.string })
        let inherited = merged.filter { seen.insert($0.0.scalar?.string ?? "").inserted }
        return .mapping(Node.Mapping(inherited + explicit, mapping.tag, mapping.style, mapping.mark))
    case let .sequence(sequence):
        return .sequence(Node.Sequence(sequence.map(resolve), sequence.tag, sequence.style, sequence.mark))
    case .scalar, .alias:
        return node
    }
}

/// Typed, strict access to one YAML mapping. Reads report a missing or
/// mistyped field; `finish(allowed:)` reports every key outside the set.
final class Fields {
    let origin: Origin
    var item: String?
    private let log: DiagnosticLog
    private var values: [String: Node] = [:]
    private(set) var keys: [String] = []

    init?(_ node: Node, file: String, item: String? = nil, log: DiagnosticLog) {
        origin = Origin(file: file, line: node.mark?.line)
        self.item = item
        self.log = log
        guard case let .mapping(mapping) = node else {
            log.error("expected a mapping", at: origin, item: item)
            return nil
        }
        for (key, value) in mapping {
            guard let name = key.scalar?.string else {
                log.error("mapping keys must be plain strings", at: origin, item: item)
                continue
            }
            if values[name] != nil {
                log.error("duplicate key `\(name)`", at: Origin(file: file, line: key.mark?.line), item: item)
            }
            values[name] = value
            keys.append(name)
        }
    }

    func node(_ key: String) -> Node? {
        values[key]
    }

    func error(_ message: String, _ key: String? = nil) {
        let line = key.flatMap { values[$0]?.mark?.line } ?? origin.line
        log.error(message, at: Origin(file: origin.file, line: line), item: item)
    }

    func string(_ key: String, required: Bool = true) -> String? {
        present(key, required: required).flatMap { scalarString($0, key) }
    }

    func int(_ key: String, required: Bool = true) -> Int? {
        present(key, required: required).flatMap { scalarInt($0, key) }
    }

    func bool(_ key: String, required: Bool = true) -> Bool? {
        present(key, required: required).flatMap { node in
            guard case let .scalar(scalar) = node, scalar.style == .plain, ["true", "false"].contains(scalar.string) else {
                error("`\(key)` must be true or false", key)
                return nil
            }
            return scalar.string == "true"
        }
    }

    func strings(_ key: String, required: Bool = true) -> [String]? {
        list(key, required: required).map { $0.compactMap { scalarString($0, key) } }
    }

    func ints(_ key: String, required: Bool = true) -> [Int]? {
        list(key, required: required).map { $0.compactMap { scalarInt($0, key) } }
    }

    func mapping(_ key: String, required: Bool = true) -> Fields? {
        present(key, required: required).flatMap { Fields($0, file: origin.file, item: item, log: log) }
    }

    /// A `{good: amount}` mapping, in written order.
    func amounts(_ key: String, required: Bool = true) -> GoodAmounts? {
        guard let fields = mapping(key, required: required) else { return nil }
        return fields.keys.compactMap { good in
            fields.int(good).map { GoodAmount(good: good, amount: $0) }
        }
    }

    func finish(allowed: Set<String>) {
        for key in keys where !allowed.contains(key) {
            error("unknown field `\(key)`", key)
        }
    }

    private func present(_ key: String, required: Bool) -> Node? {
        guard let node = values[key] else {
            if required { error("missing required field `\(key)`") }
            return nil
        }
        return node
    }

    private func list(_ key: String, required: Bool) -> [Node]? {
        guard let node = present(key, required: required) else { return nil }
        guard let sequence = node.sequence else {
            error("`\(key)` must be a list", key)
            return nil
        }
        return Array(sequence)
    }

    /// Rejects plain scalars YAML reads as another type (`no`, `1.10`,
    /// `~`), so a string field never holds a silently retyped value.
    private func scalarString(_ node: Node, _ key: String) -> String? {
        guard case let .scalar(scalar) = node else {
            error("`\(key)` must be a string", key)
            return nil
        }
        if scalar.style == .plain {
            let tag = Resolver.default.resolveTag(of: node)
            if tag != .str {
                let type = tag.rawValue.split(separator: ":").last ?? "another type"
                error("`\(key)`: YAML reads `\(scalar.string)` as \(type), not a string; quote it", key)
                return nil
            }
        }
        return scalar.string
    }

    private func scalarInt(_ node: Node, _ key: String) -> Int? {
        guard case let .scalar(scalar) = node, scalar.style == .plain,
              scalar.string.wholeMatch(of: /-?[0-9]+/) != nil, let value = Int(scalar.string)
        else {
            error("`\(key)` must be a whole number", key)
            return nil
        }
        return value
    }
}
