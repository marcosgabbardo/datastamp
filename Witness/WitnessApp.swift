import SwiftUI
import SwiftData
import UserNotifications

@main
struct WitnessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                WitnessItem.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request notification permission
                    await NotificationService.shared.requestAuthorization()
                    await NotificationService.shared.registerCategories()
                }
        }
        .modelContainer(container)
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle action
        switch response.actionIdentifier {
        case "VIEW_ACTION", UNNotificationDefaultActionIdentifier:
            // Navigate to item detail
            if let itemIdString = userInfo["itemId"] as? String {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .openTimestampDetail,
                        object: nil,
                        userInfo: ["itemId": itemIdString]
                    )
                }
            }
        case "SHARE_ACTION":
            // Share proof
            if let itemIdString = userInfo["itemId"] as? String {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .shareTimestampProof,
                        object: nil,
                        userInfo: ["itemId": itemIdString]
                    )
                }
            }
        case "CHECK_ACTION":
            // Just open app - refresh will happen automatically
            break
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTimestampDetail = Notification.Name("openTimestampDetail")
    static let shareTimestampProof = Notification.Name("shareTimestampProof")
}
