import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let isRunningTests: Bool
    private var instanceLock: ApplicationInstanceLock?
    private var statusStore: SystemStatusStore?
    private var menuBarController: MenuBarController?
    private var wakeObserver: NSObjectProtocol?

    #if DEBUG
    private var marketingCaptureObserver: NSObjectProtocol?
    private var marketingPopoverObserver: NSObjectProtocol?
    #endif

    override init() {
        isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.language: AppLanguage.system.rawValue,
            PreferenceKeys.popoverStyle: PopoverStyle.classic.rawValue,
            PreferenceKeys.popoverTransparency: PopoverAppearance.defaultTransparency,
            PreferenceKeys.hideEmptyAccessories: false,
            PreferenceKeys.scrollToAdjustVolume: false,
            PreferenceKeys.showBatteryPercentage: true,
            PreferenceKeys.animationsEnabled: true,
            PreferenceKeys.menuBarIconScale: MenuBarIconSize.defaultScale,
            PreferenceKeys.batteryColorCoding: false,
            PreferenceKeys.openOnHover: false,
            PreferenceKeys.showNetwork: true,
            PreferenceKeys.showVPN: true,
            PreferenceKeys.showVolume: true,
            PreferenceKeys.showBattery: true,
            PreferenceKeys.showAccessories: true,
            PreferenceKeys.showAudioOutput: true,
            PreferenceKeys.showMicrophone: false,
            PreferenceKeys.showBatteryTime: true,
            PreferenceKeys.lowBatteryNotificationThreshold: 20,
            PreferenceKeys.weeklyUpdateChecks: true
        ])
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }
        guard menuBarController == nil else { return }

        let instanceLock = ApplicationInstanceLock()
        guard instanceLock.acquire() else {
            #if DEBUG
            NSLog("[DuoBar] another instance already owns the menu-bar item")
            #endif
            NSApp.terminate(nil)
            return
        }
        self.instanceLock = instanceLock

        NSApp.setActivationPolicy(.accessory)
        let statusStore = SystemStatusStore()
        self.statusStore = statusStore

        #if DEBUG
        if MarketingCaptureMode.isEnabled {
            statusStore.applyMarketingCaptureState(MarketingCaptureMode.initialState)
            marketingCaptureObserver = DistributedNotificationCenter.default().addObserver(
                forName: MarketingCaptureMode.stateNotification,
                object: nil,
                queue: .main
            ) { [weak statusStore] notification in
                guard let state = notification.userInfo?["state"] as? String else { return }
                Task { @MainActor in
                    statusStore?.applyMarketingCaptureState(state)
                }
            }
        }
        #endif

        let menuBarController = MenuBarController(statusStore: statusStore)
        self.menuBarController = menuBarController
        HomebrewUpdateService.shared.start()
        Task { await LaunchAtLoginService.shared.reconcileAfterUpdate() }
        // A live process alone does not prove startup reached a responsive menu.
        DispatchQueue.main.async {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: PreferenceKeys.lastMenuBarReady)
        }

        #if DEBUG
        if MarketingCaptureMode.isEnabled, MarketingCaptureMode.opensPopover {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak menuBarController] in
                menuBarController?.setPopoverVisibleForMarketingCapture(true)
            }
        }
        if MarketingCaptureMode.isEnabled {
            marketingPopoverObserver = DistributedNotificationCenter.default().addObserver(
                forName: MarketingCaptureMode.popoverNotification,
                object: nil,
                queue: .main
            ) { [weak menuBarController] notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                Task { @MainActor in
                    menuBarController?.setPopoverVisibleForMarketingCapture(visible)
                }
            }
        }
        #endif

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak statusStore] _ in
            Task { @MainActor in
                statusStore?.refresh()
                HomebrewUpdateService.shared.checkIfDue()
            }
        }
    }

    func previewPopover() {
        menuBarController?.previewPopover()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isRunningTests else { return false }
        AboutPanel.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        #if DEBUG
        if let marketingCaptureObserver {
            DistributedNotificationCenter.default().removeObserver(marketingCaptureObserver)
            self.marketingCaptureObserver = nil
        }
        if let marketingPopoverObserver {
            DistributedNotificationCenter.default().removeObserver(marketingPopoverObserver)
            self.marketingPopoverObserver = nil
        }
        #endif

        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        menuBarController?.invalidate()
        menuBarController = nil
        statusStore = nil
        instanceLock?.release()
        instanceLock = nil
    }
}
