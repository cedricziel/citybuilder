import Foundation

/// Loads `manifest.json` and `bindings.json` from a resource bundle. Used by
/// app shells to initialize the audio stack at launch. Falls back to empty
/// (well-formed) documents when the files are missing — this is the
/// expected state for builds that haven't bundled audio content yet.
public enum AudioBundleLoader {
    public static func loadManifest(in bundle: Bundle = .main) -> Manifest {
        guard let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "Audio")
            ?? bundle.url(forResource: "manifest", withExtension: "json")
        else {
            return Manifest()
        }
        do {
            let data = try Data(contentsOf: url)
            return try Manifest.load(from: data)
        } catch {
            // Silent fallback — the audio layer is non-fatal by design.
            return Manifest()
        }
    }

    public static func loadBindings(manifest: Manifest, in bundle: Bundle = .main) -> Bindings {
        guard let url = bundle.url(forResource: "bindings", withExtension: "json", subdirectory: "Audio")
            ?? bundle.url(forResource: "bindings", withExtension: "json")
        else {
            return Bindings()
        }
        do {
            let data = try Data(contentsOf: url)
            return try Bindings.load(from: data, manifest: manifest)
        } catch {
            return Bindings()
        }
    }
}
