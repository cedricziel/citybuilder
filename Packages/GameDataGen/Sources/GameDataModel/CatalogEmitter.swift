import Foundation

/// The catalog key of a pack text: `<kind>.<id>.<field>`, the id in
/// lowerCamel like its Swift case (`building.grainFarm.name`). Design D5 of
/// `add-localization`.
func packKey(_ kind: String, _ id: String, _ field: String) -> String {
    "\(kind).\(unquotedCaseName(id)).\(field)"
}

/// The culture's key for `tier`: its own when it renames the tier, else
/// the tier's.
func tierNameKey(_ culture: Culture, _ tier: Tier) -> String {
    culture.tierName(tier) == tier.name ? packKey("tier", tier.id, "name") : packKey("culture", culture.id, "tierName.\(tier.id)")
}

/// `grain-farm` → `Grain Farm`, the English name of an item without one.
private func titleCased(_ id: String) -> String {
    id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
}

/// Writes `GameData.xcstrings`: every player-visible pack text under its
/// key, English from the packs. Other languages in the committed catalog
/// stay; a changed English value marks them for review, and a key whose
/// item is gone is dropped (design D5 of `add-localization`).
public enum CatalogEmitter {
    public struct Entry: Equatable, Sendable {
        public let english: String
        public let comment: String
    }

    public static func entries(_ data: GameData) -> [String: Entry] {
        var entries: [String: Entry] = [:]
        func add(_ kind: String, _ id: String, _ field: String, _ english: String, _ comment: String) {
            entries[packKey(kind, id, field)] = Entry(english: english, comment: comment)
        }
        for good in data.goods {
            add("good", good.id, "name", good.name, "A good's name.")
            add("good", good.id, "unit", good.unit, "What one unit of a good is counted in.")
        }
        for building in data.buildings {
            add("building", building.id, "name", building.name ?? titleCased(building.id), "A building's name.")
        }
        for tier in data.tiers {
            add("tier", tier.id, "name", tier.name, "A house tier's name.")
        }
        for culture in data.cultures {
            add("culture", culture.id, "name", culture.name, "A culture's name.")
            add("culture", culture.id, "blurb", culture.blurb, "A culture's description in the new-game dialog.")
            for tier in data.tiers where culture.tierName(tier) != tier.name {
                add("culture", culture.id, "tierName.\(tier.id)", culture.tierName(tier), "A house tier's name in this culture.")
            }
        }
        for tech in data.techs {
            add("tech", tech.id, "name", tech.name ?? titleCased(tech.id), "A technology's name.")
        }
        for age in data.ages {
            add("age", age.id, "name", age.name ?? titleCased(age.id), "An age's name.")
            add("age", age.id, "blurb", age.blurb, "An age's description.")
        }
        for order in data.orders {
            add("order", order.id, "title", order.title, "An order's title.")
            add("order", order.id, "text", order.text, "An order's text.")
        }
        for event in data.events {
            for banner in event.banners {
                let comment = "A seasonal event's banner. {names} are filled in after the lookup."
                add("seasonalEvent", event.id, "banner.\(banner.key).title", banner.title, comment)
                add("seasonalEvent", event.id, "banner.\(banner.key).text", banner.text, comment)
            }
        }
        for campaign in data.campaigns {
            add("campaign", campaign.id, "title", campaign.title, "A campaign's title.")
        }
        for chapter in data.chapters {
            add("chapter", chapter.id, "title", chapter.title, "A chapter's title.")
            add("chapter", chapter.id, "intro", chapter.intro, "A chapter's intro card.")
            add("chapter", chapter.id, "ending", chapter.ending, "A chapter's ending card.")
            add("chapter", chapter.id, "reward", chapter.reward.name, "The name of a chapter's reward.")
        }
        return entries
    }

    /// The catalog file for `data`, merged into the committed catalog's JSON.
    public static func catalog(_ data: GameData, merging committed: Data?) throws -> String {
        let old = try committed.map { try JSONSerialization.jsonObject(with: $0) as? [String: Any] ?? [:] }
        let oldStrings = old?["strings"] as? [String: Any] ?? [:]
        var strings: [String: Any] = [:]
        for (key, entry) in entries(data) {
            let previous = oldStrings[key] as? [String: Any]
            var localizations = previous?["localizations"] as? [String: Any] ?? [:]
            let oldEnglish = ((localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
            if let oldEnglish, oldEnglish != entry.english {
                for (language, value) in localizations where language != "en" {
                    localizations[language] = markedForReview(value)
                }
            }
            localizations["en"] = ["stringUnit": ["state": "translated", "value": entry.english]]
            strings[key] = ["comment": entry.comment, "extractionState": "manual", "localizations": localizations]
        }
        return CatalogJSON.write(["sourceLanguage": "en", "strings": strings, "version": "1.0"]) + "\n"
    }

    private static func markedForReview(_ localization: Any) -> Any {
        guard var localization = localization as? [String: Any], var unit = localization["stringUnit"] as? [String: Any] else {
            return localization
        }
        unit["state"] = "needs_review"
        localization["stringUnit"] = unit
        return localization
    }
}

/// JSON the way the committed catalogs are written: two-space indent,
/// `"key" : value`, keys sorted, non-ASCII kept as is.
enum CatalogJSON {
    static func write(_ value: Any, indent: String = "") -> String {
        switch value {
        case let object as [String: Any]:
            guard !object.isEmpty else { return "{}" }
            let inner = indent + "  "
            let members = object.keys.sorted().map { inner + quoted($0) + " : " + write(object[$0]!, indent: inner) }
            return "{\n" + members.joined(separator: ",\n") + "\n" + indent + "}"
        case let array as [Any]:
            guard !array.isEmpty else { return "[]" }
            let inner = indent + "  "
            return "[\n" + array.map { inner + write($0, indent: inner) }.joined(separator: ",\n") + "\n" + indent + "]"
        case let text as String:
            return quoted(text)
        case let number as NSNumber:
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? (number.boolValue ? "true" : "false") : number.stringValue
        default:
            return "null"
        }
    }

    private static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}
