import SwiftUI
import RevenueCat

@main
struct AIHeadshotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()

    init() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppConfig.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Purchases.shared.setPushToken(deviceToken)
    }
}

enum AppConfig {
    static let revenueCatAPIKey  = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? "YOUR_REVENUECAT_API_KEY"
    static let baseURL           = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://api.aiheadshot.app"
    static let oneSignalAppId    = ProcessInfo.processInfo.environment["ONESIGNAL_APP_ID"] ?? "YOUR_ONESIGNAL_APP_ID"
    static let proEntitlement    = "pro"
    static let monthlyProductId  = "com.aiheadshot.pro.monthly"
    static let annualProductId   = "com.aiheadshot.pro.annual"
}

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
            } else {
                switch coordinator.currentScreen {
                case .home:
                    HomeView()
                case .camera:
                    CameraView()
                case .styleSelector(let photos):
                    StyleSelectorView(capturedPhotos: photos)
                case .progress(let jobId):
                    GenerationProgressView(jobId: jobId)
                case .results(let jobId):
                    ResultsGalleryView(jobId: jobId)
                case .paywall:
                    PaywallView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
