import Foundation

enum HelpTab: CaseIterable, Identifiable {
    case overview
    case features
    case system

    var id: Self { self }

    @MainActor
    func title(appState: AppState) -> String {
        switch self {
        case .overview: return appState.tr(.tabOverview)
        case .features: return appState.tr(.tabFeatures)
        case .system: return appState.tr(.tabSystem)
        }
    }
}
