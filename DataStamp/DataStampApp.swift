import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks

@main
struct DataStampApp: App {
    @StateObject private var syncService = CloudKitSyncService()
    @Environment(\.scenePhase) private var scenePhase
    
    let container: ModelContainer
    let storageService = StorageService()
    
    init() {
        do {
            let schema = Schema([
                DataStampItem.self,
                Folder.self
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
            
            // Configure background task manager
            BackgroundTaskManager.shared.configure(with: container)
            
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncService)
                .task {
                    await setupNotifications()
                    await syncService.configure(with: container.mainContext, storage: storageService)
                    
                    // Initial sync (only if available)
                    if syncService.isAvailable {
                        await syncService.sync()
                    }
                    
                    // Clear badge when app opens (user has seen confirmations)
                    BackgroundTaskManager.clearUnseenConfirmations()
                    
                    // Check pending timestamps when app opens
                    await BackgroundTaskManager.shared.checkNow()
                    
                    // Schedule background refresh
                    BackgroundTaskManager.shared.scheduleBackgroundRefresh()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // Clear unseen confirmations badge when user opens app
                BackgroundTaskManager.clearUnseenConfirmations()
                
                // Check pending timestamps when app becomes active
                Task {
                    await BackgroundTaskManager.shared.checkNow()
                }
            case .background:
                // Schedule background refresh when going to background
                BackgroundTaskManager.shared.scheduleBackgroundRefresh()
            default:
                break
            }
        }
    }
    
    private func setupNotifications() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("Notifications authorized: \(granted)")
            
            if granted {
                // Register notification categories for actions
                NotificationService.shared.registerCategories()
            }
        } catch {
            print("Notification auth error: \(error)")
        }
    }
}
