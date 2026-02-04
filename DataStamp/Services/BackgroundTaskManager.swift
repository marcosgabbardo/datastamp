import Foundation
import BackgroundTasks
import SwiftData
import UserNotifications

/// Manages background tasks for checking and upgrading pending timestamps
@MainActor
final class BackgroundTaskManager {
    
    // MARK: - Constants
    
    static let shared = BackgroundTaskManager()
    
    /// Background task identifier - must match Info.plist
    static let taskIdentifier = "com.makiavel.datestamp.refresh"
    
    /// UserDefaults key for unseen confirmations count
    private static let unseenConfirmationsKey = "unseenConfirmationsCount"
    
    /// Minimum interval between background refreshes (15 minutes)
    private let minimumInterval: TimeInterval = 15 * 60
    
    // MARK: - Unseen Confirmations Badge
    
    /// Get the current unseen confirmations count
    static var unseenConfirmationsCount: Int {
        UserDefaults.standard.integer(forKey: unseenConfirmationsKey)
    }
    
    /// Increment unseen confirmations count
    static func incrementUnseenConfirmations() {
        let current = unseenConfirmationsCount
        UserDefaults.standard.set(current + 1, forKey: unseenConfirmationsKey)
    }
    
    /// Clear unseen confirmations (call when user views the list)
    static func clearUnseenConfirmations() {
        UserDefaults.standard.set(0, forKey: unseenConfirmationsKey)
        Task { @MainActor in
            await NotificationService.shared.updateBadge(pendingCount: 0)
        }
    }
    
    // MARK: - Properties
    
    private var modelContainer: ModelContainer?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Setup
    
    /// Configure the background task manager with model container
    func configure(with container: ModelContainer) {
        self.modelContainer = container
        registerBackgroundTask()
    }
    
    /// Register the background task with the system
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await self?.handleBackgroundRefresh(task: bgTask)
            }
        }
        
        print("Background task registered: \(Self.taskIdentifier)")
    }
    
    // MARK: - Scheduling
    
    /// Schedule the next background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled for ~\(minimumInterval/60) minutes from now")
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
    
    /// Cancel any pending background refresh
    func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }
    
    // MARK: - Task Handling
    
    /// Handle background refresh task
    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        print("Background refresh started at \(Date())")
        
        // Schedule the next refresh
        scheduleBackgroundRefresh()
        
        // Set expiration handler
        task.expirationHandler = {
            print("Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Check and upgrade pending timestamps
        let success = await checkPendingTimestamps()
        
        task.setTaskCompleted(success: success)
        print("Background refresh completed: \(success)")
    }
    
    // MARK: - Timestamp Checking
    
    /// Check all pending timestamps and upgrade if possible
    @discardableResult
    func checkPendingTimestamps() async -> Bool {
        guard let container = modelContainer else {
            print("BackgroundTaskManager: No model container configured")
            return false
        }
        
        let context = container.mainContext
        let manager = DataStampManager()
        
        // Fetch all timestamps and filter for pending
        let descriptor = FetchDescriptor<DataStampItem>()
        
        guard let allItems = try? context.fetch(descriptor) else {
            print("BackgroundTaskManager: Failed to fetch items")
            return false
        }
        
        // Filter for submitted status
        let pendingItems = allItems.filter { $0.status == .submitted }
        
        guard !pendingItems.isEmpty else {
            print("BackgroundTaskManager: No pending timestamps to check")
            // Update badge to 0
            await NotificationService.shared.updateBadge(pendingCount: 0)
            return true
        }
        
        print("BackgroundTaskManager: Checking \(pendingItems.count) pending timestamps")
        
        var confirmedCount = 0
        
        for item in pendingItems {
            // Try to upgrade the timestamp
            let wasConfirmed = await upgradeTimestamp(item, manager: manager, context: context)
            
            if wasConfirmed {
                confirmedCount += 1
                
                // Increment unseen confirmations badge
                Self.incrementUnseenConfirmations()
                
                // Send notification
                await NotificationService.shared.notifyConfirmation(
                    title: item.title ?? "Timestamp",
                    itemId: item.id,
                    blockHeight: item.bitcoinBlockHeight
                )
            }
        }
        
        // Update badge with unseen confirmations count (not pending count)
        await NotificationService.shared.updateBadge(pendingCount: Self.unseenConfirmationsCount)
        
        print("BackgroundTaskManager: \(confirmedCount) timestamps confirmed, \(pendingItems.count - confirmedCount) still pending")
        
        return true
    }
    
    /// Upgrade a single timestamp if possible
    private func upgradeTimestamp(
        _ item: DataStampItem,
        manager: DataStampManager,
        context: ModelContext
    ) async -> Bool {
        // Only process submitted items
        guard item.status == .submitted else { return false }
        
        // Try to upgrade
        await manager.upgradeTimestamp(item, context: context)
        
        // Check if it was confirmed
        if item.status == .confirmed {
            // Extract block info
            _ = await manager.extractBlockInfo(for: item, context: context)
            return true
        }
        
        return false
    }
    
    // MARK: - Manual Check
    
    /// Manually trigger a check (e.g., when app becomes active)
    func checkNow() async {
        await checkPendingTimestamps()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension BackgroundTaskManager {
    /// Simulate background task for testing
    /// Call from debugger: e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.makiavel.datestamp.refresh"]
    func simulateBackgroundTask() {
        print("To simulate background task, run in debugger:")
        print("e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"\(Self.taskIdentifier)\"]")
    }
}
#endif
