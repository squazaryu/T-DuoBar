enum PreferenceKeys {
    static let language = "appearance.language"
    static let popoverStyle = "appearance.popoverStyle"
    static let popoverTransparency = "appearance.popoverTransparency"
    static let hideEmptyAccessories = "menu.hideEmptyAccessories"
    static let scrollToAdjustVolume = "duoBar.scrollToAdjustVolume"
    static let menuBarBatteryPercentage = "appearance.menuBarBatteryPercentage"
    static let showBatteryPercentage = "showBatteryPercentage"
    static let animationsEnabled = "animationsEnabled"
    static let menuBarIconScale = MenuBarIconSize.preferenceKey
    static let batteryColorCoding = "batteryColorCoding"
    static let adaptiveRingPriority = "adaptiveRingPriority"
    static let adaptiveRingColorCoding = "adaptiveRingColorCoding"
    static let openOnHover = "duoBar.openOnHover"

    static let showNetwork = "menu.showNetwork"
    static let showVPN = "menu.showVPN"
    static let showVolume = "menu.showVolume"
    static let showBattery = "menu.showBattery"
    static let showAccessories = "menu.showAccessories"
    static let showAudioOutput = "menu.showAudioOutput"
    static let showMicrophone = "menu.showMicrophone"
    static let showBatteryTime = "menu.showBatteryTime"
    static let menuSectionOrder = "menu.sectionOrder"
    static let favoriteOutputUIDs = "audio.favoriteOutputUIDs"
    static let lowBatteryNotificationEnabled = "battery.notificationEnabled"
    static let lowBatteryNotificationThreshold = "battery.notificationThreshold"
    static let lowBatteryNotificationSound = "battery.notificationSound"

    static let weeklyUpdateChecks = "updates.weeklyChecks"
    static let lastUpdateCheck = "updates.lastSuccess"
    static let lastUpdateAttempt = "updates.lastAttempt"
    static let lastNotifiedUpdate = "updates.lastNotified"
    static let cachedHomebrewRelease = "updates.cachedRelease"

    #if DEBUG
    static let simulateDesktopMac = "debug.simulateDesktopMac"
    #endif
}
