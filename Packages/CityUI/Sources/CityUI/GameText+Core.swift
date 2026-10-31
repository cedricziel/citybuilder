import CityCore

/// Text for what CityCore hands over as keys (design D4 of `add-localization`).
public extension GameText {
    /// The message's template with each `{name}` filled by its argument,
    /// formatted for the language.
    static func string(_ message: GameMessage, in language: Language = .current) -> String {
        message.args.reduce(string(message.key, in: language)) { text, arg in
            let value = switch arg.value {
            case let .int(value): number(value, in: language)
            case let .money(amount): HUDViewModel.formatMoney(amount, locale: language.locale)
            }
            return text.replacingOccurrences(of: "{\(arg.key)}", with: value)
        }
    }

    /// "Autumn 1203"; years up to 0 read before Christ, year 0 being 1 BC
    /// (design D2 of `add-historical-ages`). The year goes in as text:
    /// `%lld` would group it ("1.203") in German.
    static func date(_ date: GameDate, in language: Language = .current) -> String {
        let season = string(date.season.nameKey, in: language)
        return date.year > 0
            ? string("date.ad", season, "\(date.year)", in: language)
            : string("date.bc", season, "\(1 - date.year)", in: language)
    }
}
