import Foundation

/// The Claude Code edit hooks for game data. `pre` blocks hand edits to
/// the generated Swift; `post` validates the packs after a pack edit.
/// Every other edit, and any input the hook can't read, passes through
/// untouched: the hooks run for every agent edit in the repository.
public enum GameDataHook {
    public enum Phase: String, Sendable {
        case pre, post
    }

    /// Exit status 2 blocks the edit (`pre`) or reports `message` back to
    /// the agent (`post`); 0 lets the edit through.
    public struct Outcome: Equatable, Sendable {
        public var status: Int32
        public var message: String

        static let pass = Outcome(status: 0, message: "")
    }

    static let dataPath = "Packages/CityCore/GameData/"
    static let generatedPath = "Packages/CityCore/Sources/CityCore/Generated/"

    /// `input` is the hook's JSON from Claude Code.
    public static func run(_ phase: Phase, input: Data) -> Outcome {
        guard let json = try? JSONSerialization.jsonObject(with: input) as? [String: Any],
              let toolInput = json["tool_input"] as? [String: Any],
              let path = toolInput["file_path"] as? String
        else { return .pass }

        switch phase {
        case .pre:
            guard checkout(of: path, containing: generatedPath) != nil else { return .pass }
            return Outcome(status: 2, message: """
            \(path) is generated from the content packs; don't edit it by hand. \
            Change the pack under \(dataPath) instead, then run `make gamedata` to regenerate.
            """)
        case .post:
            guard path.hasSuffix(".yaml"), let root = checkout(of: path, containing: dataPath) else { return .pass }
            let data = URL(fileURLWithPath: root + dataPath)
            switch GameDataLoader.load(from: DirectorySource(root: data)) {
            case .success:
                return .pass
            case let .failure(errors):
                return Outcome(status: 2, message: "The game data no longer validates after this edit:\n\(errors)")
            }
        }
    }

    /// The checkout root (with a trailing slash, or empty for a relative
    /// path) when `path` lies under `directory` of a checkout.
    private static func checkout(of path: String, containing directory: String) -> String? {
        if path.hasPrefix(directory) { return "" }
        guard let range = path.range(of: "/" + directory) else { return nil }
        return String(path[...range.lowerBound])
    }
}
