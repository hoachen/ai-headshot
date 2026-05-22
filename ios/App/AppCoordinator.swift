import SwiftUI
import Combine

enum AppScreen: Equatable {
    case home
    case camera
    case styleSelector(photos: [UIImage])
    case progress(jobId: String)
    case results(jobId: String)
    case paywall
    case settings

    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.camera, .camera), (.paywall, .paywall), (.settings, .settings):
            return true
        case (.styleSelector, .styleSelector):
            return true
        case (.progress(let a), .progress(let b)):
            return a == b
        case (.results(let a), .results(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var isPresentingPaywall = false
    @Published var isPresentingSettings = false

    private var history: [AppScreen] = []

    func navigate(to screen: AppScreen) {
        history.append(currentScreen)
        currentScreen = screen
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        currentScreen = previous
    }

    func startCapture() {
        navigate(to: .camera)
    }

    func captureComplete(photos: [UIImage]) {
        navigate(to: .styleSelector(photos: photos))
    }

    func generationStarted(jobId: String) {
        navigate(to: .progress(jobId: jobId))
    }

    func generationComplete(jobId: String) {
        navigate(to: .results(jobId: jobId))
    }

    func showPaywall() {
        isPresentingPaywall = true
    }

    func showSettings() {
        isPresentingSettings = true
    }

    func goHome() {
        history.removeAll()
        currentScreen = .home
    }
}
