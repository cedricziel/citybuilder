#if canImport(SwiftUI)
import CityUI
import SwiftUI

/// SwiftUI view that lists every audio asset's title, author, license, and
/// (for non-CC0 entries) attribution text. Per spec `audio-playback`
/// "Credits view reads the manifest" and `platform-shells` "Settings
/// exposes credits".
///
/// Pass a parsed `Manifest`; the view does no file I/O. The app shell
/// loads the JSON, validates it, and constructs the view.
@available(iOS 18, macOS 15, *)
public struct CreditsView: View {
    public let manifest: Manifest

    public init(manifest: Manifest) {
        self.manifest = manifest
    }

    public var body: some View {
        List {
            Section {
                Text(l10n: "credits.intro")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(manifest.entries, id: \.path) { entry in
                CreditsRow(entry: entry)
            }
            if manifest.entries.isEmpty {
                Text(l10n: "credits.empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(GameText.string("credits.title"))
    }
}

@available(iOS 18, macOS 15, *)
private struct CreditsRow: View {
    let entry: Manifest.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title).font(.headline)
            Text(l10n: "credits.by", entry.author).font(.subheadline).foregroundStyle(.secondary)
            Text(entry.license.rawValue).font(.caption).foregroundStyle(.tertiary)
            if let attribution = entry.attribution, !attribution.isEmpty {
                Text(attribution).font(.caption).italic()
            }
            if let url = URL(string: entry.source) {
                #if os(tvOS)
                Text(url.absoluteString).font(.caption).foregroundStyle(.secondary)
                #else
                Link(GameText.string("credits.source"), destination: url).font(.caption)
                #endif
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
