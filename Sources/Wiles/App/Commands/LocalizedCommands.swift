import SwiftUI

/// Shared localization helper for the `Commands`-conforming menu structs in this directory.
/// Each conformer just needs its own `sharedPreferences` stored property; this default
/// implementation of `tr(_:)` replaces the identical private method that used to be duplicated
/// across every menu file.
protocol LocalizedCommands: Commands {
    var sharedPreferences: PreferencesStore { get }
}

extension LocalizedCommands {
    func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appearance.appLanguage)
    }
}
