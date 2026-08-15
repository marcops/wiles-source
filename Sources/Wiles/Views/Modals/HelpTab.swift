import Foundation

enum HelpTab: CaseIterable, Identifiable {
    case overview
    case features
    case system

    var id: Self {
        self
    }

    @MainActor
    func title(appState: AppState) -> String {
        switch self {
        case .overview: appState.tr(.tabOverview)
        case .features: appState.tr(.tabFeatures)
        case .system: appState.tr(.tabSystem)
        }
    }
}
