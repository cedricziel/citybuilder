import CityCore

// Pack text in the player's language. CityCore's generated catalogs carry
// keys into `GameData.xcstrings`, which GameDataGen writes from the packs
// (design D5 of `add-localization`).

extension Good {
    var displayName: String {
        GameText.string(nameKey)
    }

    /// What one unit is counted in: "logs", "Stämme".
    var stackUnit: String {
        GameText.string(unitKey)
    }
}

extension GoodSpec {
    var displayName: String {
        good.displayName
    }

    var stackUnit: String {
        good.stackUnit
    }
}

extension BuildingKind {
    var displayName: String {
        GameText.string(nameKey)
    }
}

extension Tech {
    var displayName: String {
        GameText.string(nameKey)
    }
}

extension Age {
    var displayName: String {
        GameText.string(nameKey)
    }

    var blurb: String {
        GameText.string(blurbKey)
    }
}

extension Culture {
    var displayName: String {
        GameText.string(nameKey)
    }

    var blurb: String {
        GameText.string(blurbKey)
    }
}

extension HouseTier {
    var displayName: String {
        GameText.string(nameKey)
    }

    /// The culture's name for this tier.
    func displayName(in culture: Culture) -> String {
        GameText.string(nameKey(in: culture))
    }
}

extension OrderTemplate {
    var title: String {
        GameText.string(titleKey)
    }

    var text: String {
        GameText.string(textKey)
    }
}

extension Campaign {
    var displayTitle: String {
        titleKey.map { GameText.string($0, orStored: title) } ?? title
    }
}

/// A chapter from the packs reads its text from the catalog; one built in
/// code, or one whose key the catalog lacks, shows what it stores.
extension Chapter {
    var displayTitle: String {
        text("title", stored: title)
    }

    var displayIntro: String {
        text("intro", stored: intro)
    }

    var displayEnding: String {
        text("ending", stored: ending)
    }

    var rewardName: String {
        text("reward", stored: reward.name)
    }

    private func text(_ field: String, stored: String) -> String {
        textKey.map { GameText.string("\($0).\(field)", orStored: stored) } ?? stored
    }
}

extension ChapterReward {
    /// The name as the pack wrote it.
    var name: String {
        switch self {
        case let .banner(name), let .decor(name), let .mapPreset(name): name
        }
    }
}
