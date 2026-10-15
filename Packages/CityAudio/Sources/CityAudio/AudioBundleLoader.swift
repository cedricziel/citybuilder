import Foundation
import os

/// Loads `manifest.json` and `bindings.json` from a resource bundle. Used by
/// app shells to initialize the audio stack at launch. Falls back to empty
/// (well-formed) documents when the files are missing — this is the
/// expected state for builds that haven't bundled audio content yet. A file
/// that is present but fails to load is reported through `report` (a fault
/// in the system log by default) before falling back, so a broken document
/// cannot silence the game unnoticed.
public enum AudioBundleLoader {
    private static let logger = Logger(subsystem: "com.cedricziel.citybuilder", category: "audio")

    public static func logFault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }

    public static func loadManifest(in bundle: Bundle = .main, report: (String) -> Void = logFault) -> Manifest {
        guard let url = url(of: "manifest", in: bundle) else { return Manifest() }
        do {
            return try Manifest.load(from: Data(contentsOf: url))
        } catch {
            report("manifest.json failed to load, so the audio credits are empty: \(error)")
            return Manifest()
        }
    }

    public static func loadBindings(
        manifest: Manifest,
        in bundle: Bundle = .main,
        report: (String) -> Void = logFault
    ) -> Bindings {
        guard let url = url(of: "bindings", in: bundle) else { return Bindings() }
        do {
            return try Bindings.load(from: Data(contentsOf: url), manifest: manifest)
        } catch {
            report("bindings.json failed to load, so no cue will play: \(error)")
            return Bindings()
        }
    }

    private static func url(of name: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: "json", subdirectory: "Audio")
            ?? bundle.url(forResource: name, withExtension: "json")
    }
}
