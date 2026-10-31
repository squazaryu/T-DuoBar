import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private static let hoverCloseDelay: TimeInterval = 0.25

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var glassPanel: GlassPopoverPanel?
    private var popoverContentController: NSViewController?
    private var popoverContentHeight: CGFloat = 316
    private var popoverContentWidth: CGFloat = 304
    private var desiredPopoverWidth: CGFloat { MenuPresentation.width(defaults: defaults) }
    private var isMenuShown: Bool { popover.isShown || glassPanel?.isVisible == true }
    private let statusStore: SystemStatusStore
    private let defaults: UserDefaults
    private var hostingView: PassthroughHostingView<DuoStatusView>?
    private var popoverTrackingView: HoverTrackingContainerView?
    private var popoverBackgroundView: PopoverBackgroundView?
    private var lengthAnimationTimer: Timer?
    private var pendingHoverClose: DispatchWorkItem?
    private var hoverCloseGeneration: UInt = 0
    private var defaultsObserver: NSObjectProtocol?
    private var applicationResignObserver: NSObjectProtocol?
    private var accessibilityDisplayObserver: NSObjectProtocol?
    private var volumeScrollMonitor: Any?
    private var statusItemMouseMonitor: Any?
    private var volumeScroll = VolumeScrollAccumulator()
    private var lastLanguageRaw: String
    private var hoverInteraction: HoverPopoverInteraction
    private var isInvalidated = false
    private var isPopoverVisible = false

    init(statusStore: SystemStatusStore, defaults: UserDefaults = .standard) {
        self.statusStore = statusStore
        self.defaults = defaults
        lastLanguageRaw = defaults.string(forKey: PreferenceKeys.language) ?? AppLanguage.system.rawValue
        hoverInteraction = HoverPopoverInteraction(isEnabled: defaults.bool(forKey: PreferenceKeys.openOnHover))
        statusItem = NSStatusBar.system.statusItem(
            withLength: MenuBarIconSize.statusItemWidth(for: MenuBarIconSize.storedScale())
        )
        super.init()
        configureStatusItem()
        configurePopover()
        installStatusItemMouseMonitor()
        observePreferences()
        observeApplicationActivity()
        observeAccessibilityDisplayOptions()
        updateVolumeScrollMonitor()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: Self.statusItemActionEvents)
        button.image = nil
        button.title = ""
        button.toolTip = nil

        let rootView = DuoStatusView(statusStore: statusStore) { [weak self] width in
            self?.setStatusItemLength(width)
        }
        let hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.onHoverChanged = { [weak self] isInside in
            guard let self else { return }
            let commands = isInside
                ? self.hoverInteraction.statusItemEntered()
                : self.hoverInteraction.statusItemExited()
            self.perform(commands)
        }
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    var tooltipText: String? { statusItem.button?.toolTip }
    var menuWindow: NSWindow? {
        glassPanel?.isVisible == true ? glassPanel : popover.contentViewController?.view.window
    }

    private func configurePopover() {
        updatePopoverBehavior()
        popover.delegate = self
        popover.animates = true
        popover.contentSize = NSSize(width: desiredPopoverWidth, height: 316)
        let hostingController = NSHostingController(
            rootView: StatusPopoverView(statusStore: statusStore, onHeightChange: { [weak self] height in
                DispatchQueue.main.async {
                    guard let self, !self.isInvalidated,
                          abs(self.popoverContentHeight - height) > 0.5 || abs(self.popoverContentWidth - self.desiredPopoverWidth) > 0.5 else { return }
                    self.popoverContentHeight = height
                    self.popoverContentWidth = self.desiredPopoverWidth
                    let size = NSSize(width: self.desiredPopoverWidth, height: height)
                    if self.popover.contentViewController != nil { self.popover.contentSize = size }
                    self.glassPanel?.resizeContent(to: size)
                }
            }) { [weak self] in
                self?.closePopoverFromContent()
            }.defaultAppStorage(defaults)
        )
        let trackingView = HoverTrackingContainerView()
        trackingView.onHoverChanged = { [weak self] isInside in
            guard let self else { return }
            let commands = isInside
                ? self.hoverInteraction.popoverEntered()
                : self.hoverInteraction.popoverExited()
            self.perform(commands)
        }
        let contentViewController = NSViewController()
        contentViewController.view = trackingView
        let backgroundView = PopoverBackgroundView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(backgroundView)
        popoverBackgroundView = backgroundView
        contentViewController.addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor)
        ])
        popover.contentViewController = contentViewController
        popoverContentController = contentViewController
        popoverTrackingView = trackingView
        updatePopoverAppearance()
    }

    @objc private func togglePopover() {
        guard !isInvalidated else { return }
        if Self.opensContextMenu(for: NSApp.currentEvent), let event = NSApp.currentEvent,
           let button = statusItem.button {
            perform(hoverInteraction.contextMenuOpened())
            defer { perform(hoverInteraction.contextMenuClosed()) }
            NSMenu.popUpContextMenu(makeContextMenu(), with: event, for: button)
            return
        }
        perform(hoverInteraction.statusItemClicked())
    }

    static let statusItemActionEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseUp]

    private func installStatusItemMouseMonitor() {
        statusItemMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.filterStatusItemMouseDown(event)
        }
    }

    /// Intercept before NSWindow/NSButton tracking can transfer focus and hide
    /// the popup. Consuming this event prevents a second target/action dispatch.
    func filterStatusItemMouseDown(_ event: NSEvent, relativeTo anchor: NSView? = nil) -> NSEvent? {
        guard !isInvalidated, !hoverInteraction.isContextMenuOpen,
              event.type == .leftMouseDown, !event.modifierFlags.contains(.control),
              let button = anchor ?? statusItem.button,
              let window = button.window, event.window === window,
              button.bounds.contains(button.convert(event.locationInWindow, from: nil)) else { return event }
        perform(hoverInteraction.statusItemClicked(), anchor: button)
        return nil
    }

    static func opensContextMenu(for event: NSEvent?) -> Bool {
        guard let event else { return false }
        return event.type == .rightMouseUp ||
            ([.leftMouseDown, .leftMouseUp].contains(event.type) && event.modifierFlags.contains(.control))
    }

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: AppIdentity.name)
        menu.autoenablesItems = false
        let settings = NSMenuItem(title: localized("Settings…"), action: #selector(openSettingsFromContextMenu), keyEquivalent: ",")
        settings.target = self
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)
        let updates = NSMenuItem(title: localized("Check for updates…"), action: #selector(checkUpdatesFromContextMenu), keyEquivalent: "")
        updates.target = self
        updates.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        updates.isEnabled = !HomebrewUpdateService.shared.isChecking
        menu.addItem(updates)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: localized("Quit T-DuoBar"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    @objc private func openSettingsFromContextMenu() {
        Task { @MainActor in SettingsWindowOpener.open() }
    }

    @objc private func checkUpdatesFromContextMenu() {
        Task { @MainActor in await HomebrewUpdateService.shared.checkManually() }
    }

    private func showPopover(relativeTo anchor: NSView? = nil) {
        guard !isMenuShown, let button = anchor ?? statusItem.button, let contentController = popoverContentController else { return }

        updatePopoverBehavior()
        updatePopoverAppearance()
        statusStore.refresh()
        NSApp.activate(ignoringOtherApps: true)
        let size = NSSize(width: desiredPopoverWidth, height: popoverContentHeight)
        if usesGlassPanel {
            popover.contentViewController = nil
            let panel = glassPanel ?? makeGlassPanel()
            glassPanel = panel
            panel.setHostedController(contentController)
            panel.show(relativeTo: button, contentSize: size)
        } else {
            glassPanel?.setHostedController(nil)
            popover.contentViewController = contentController
            popover.contentSize = size
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        // Let the accessory app finish activating and the popover become key
        // before asking CoreLocation to present its native authorization UI.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isInvalidated, self.isMenuShown,
                  self.defaults.object(forKey: PreferenceKeys.showNetwork) as? Bool ?? true else { return }
            self.statusStore.requestWiFiSSIDAccess(trigger: .popoverOpened)
        }
    }

    func previewPopover(relativeTo anchor: NSView? = nil) {
        guard !isInvalidated, !isMenuShown else { return }
        perform(hoverInteraction.statusItemClicked(), anchor: anchor)
    }

    private var usesGlassPanel: Bool {
        PopoverAppearance(defaults: defaults).usesLiquidGlass(
            supportsLiquidGlass: PopoverStyle.supportsLiquidGlass,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    }

    private func makeGlassPanel() -> GlassPopoverPanel {
        let panel = GlassPopoverPanel()
        panel.onShow = { [weak self] in self?.menuDidShow() }
        panel.onWillClose = { [weak self] in self?.menuWillClose() }
        panel.onClose = { [weak self] in self?.menuDidClose() }
        return panel
    }

    private func closePopover() {
        if glassPanel?.isVisible == true { glassPanel?.dismiss() }
        if popover.isShown { popover.performClose(nil) }
    }

    private func closePopoverFromContent() {
        perform(hoverInteraction.popoverClosedExternally())
        closePopover()
    }

    private func perform(_ commands: [HoverPopoverCommand], anchor: NSView? = nil) {
        guard !isInvalidated else { return }
        for command in commands {
            switch command {
            case .open:
                showPopover(relativeTo: anchor)
            case .close:
                closePopover()
            case .scheduleClose:
                scheduleHoverClose()
            case .cancelClose:
                cancelHoverClose()
            }
        }
    }

    private func scheduleHoverClose() {
        cancelHoverClose()
        let generation = hoverCloseGeneration
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.hoverCloseGeneration == generation else { return }
                self.pendingHoverClose = nil
                self.perform(self.hoverInteraction.closeDelayElapsed())
            }
        }
        pendingHoverClose = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.hoverCloseDelay,
            execute: workItem
        )
    }

    private func cancelHoverClose() {
        hoverCloseGeneration &+= 1
        pendingHoverClose?.cancel()
        pendingHoverClose = nil
    }

    private func observePreferences() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let enabled = self.defaults.bool(forKey: PreferenceKeys.openOnHover)
                let commands = self.hoverInteraction.setEnabled(enabled)
                self.updatePopoverBehavior()
                self.updatePopoverAppearance()
                if abs(self.popoverContentWidth - self.desiredPopoverWidth) > 0.5 {
                    self.popoverContentWidth = self.desiredPopoverWidth
                    let size = NSSize(width: self.desiredPopoverWidth, height: self.popoverContentHeight)
                    if self.popover.contentViewController != nil { self.popover.contentSize = size }
                    self.glassPanel?.resizeContent(to: size)
                }
                self.perform(commands)
                self.updateAccessoryPolling()
                self.updateVPNMonitoring()
                if !self.defaults.bool(forKey: PreferenceKeys.networkDiagnostics),
                   self.statusStore.networkDiagnostics.isRunning || self.statusStore.networkDiagnostics.result != nil {
                    self.statusStore.networkDiagnostics.cancel()
                }
                self.updateVolumeScrollMonitor()
                let language = self.defaults.string(forKey: PreferenceKeys.language) ?? AppLanguage.system.rawValue
                if language != self.lastLanguageRaw {
                    self.lastLanguageRaw = language
                    HomebrewUpdateService.shared.refreshNotificationLanguage()
                }
            }
        }
    }

    private func observeApplicationActivity() {
        applicationResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.perform(self.hoverInteraction.applicationResignedActive())
            }
        }
    }

    var hasVolumeScrollMonitor: Bool { volumeScrollMonitor != nil }

    private func updateVolumeScrollMonitor() {
        let enabled = !isInvalidated && defaults.bool(forKey: PreferenceKeys.scrollToAdjustVolume)
        if !enabled {
            if let volumeScrollMonitor { NSEvent.removeMonitor(volumeScrollMonitor) }
            volumeScrollMonitor = nil
            volumeScroll.reset()
        } else if volumeScrollMonitor == nil {
            // App-local, limited to this status button. No global event tap or
            // Accessibility permission, and no interception of normal clicks.
            volumeScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let button = self.statusItem.button,
                      let window = button.window, event.window === window,
                      button.bounds.contains(button.convert(event.locationInWindow, from: nil)) else { return event }
                let handled = self.handleVolumeScroll(deltaY: Double(event.scrollingDeltaY),
                    precise: event.hasPreciseScrollingDeltas, inverted: event.isDirectionInvertedFromDevice,
                    momentum: !event.momentumPhase.isEmpty, timestamp: event.timestamp,
                    beginsGesture: event.phase.contains(.began),
                    endsGesture: !event.phase.intersection([.ended, .cancelled]).isEmpty)
                return handled ? nil : event
            }
        }
    }

    @discardableResult
    func handleVolumeScroll(deltaY: Double, precise: Bool, inverted: Bool, momentum: Bool,
                            timestamp: TimeInterval, beginsGesture: Bool = false, endsGesture: Bool = false) -> Bool {
        guard !isInvalidated, !hoverInteraction.isContextMenuOpen,
              defaults.bool(forKey: PreferenceKeys.scrollToAdjustVolume),
              let uid = statusStore.status.audio.defaultOutput?.uid,
              statusStore.status.audio.volume.isSettable,
              let level = statusStore.status.audio.volume.level, level.isFinite else {
            volumeScroll.reset()
            return false
        }
        if endsGesture { volumeScroll.reset(); return true }
        guard let change = volumeScroll.change(deltaY: deltaY, precise: precise, inverted: inverted,
            momentum: momentum, timestamp: timestamp, deviceUID: uid, beginsGesture: beginsGesture) else { return true }
        let base = statusStore.status.audio.volume.isMuted ? 0 : level
        let target = min(max(base + change, 0), 1)
        if target != base { _ = statusStore.setVolume(target) }
        return true
    }

    private func updatePopoverBehavior() {
        popover.animates = defaults.object(forKey: PreferenceKeys.animationsEnabled) as? Bool ?? true
        #if DEBUG
        if MarketingCaptureMode.isEnabled {
            popover.behavior = .applicationDefined
            return
        }
        #endif
        popover.behavior = hoverInteraction.isEnabled ? .applicationDefined : .transient
    }

    private func observeAccessibilityDisplayOptions() {
        accessibilityDisplayObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updatePopoverAppearance() }
        }
    }

    private func updatePopoverAppearance() {
        guard !isInvalidated else { return }
        popoverBackgroundView?.fillOpacity = PopoverAppearance(defaults: defaults).backgroundOpacity(
            supportsLiquidGlass: PopoverStyle.supportsLiquidGlass,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
        if isMenuShown, usesGlassPanel != (glassPanel?.isVisible == true) {
            closePopover()
            previewPopover()
        }
    }

    private func updateAccessoryPolling() {
        let enabled = defaults.object(forKey: PreferenceKeys.showAccessories) as? Bool ?? true
        if !isInvalidated && isPopoverVisible && enabled {
            statusStore.accessoryBatteryService.start()
        } else {
            statusStore.accessoryBatteryService.stop()
        }
    }

    private func updateVPNMonitoring() {
        let enabled = defaults.object(forKey: PreferenceKeys.showVPN) as? Bool ?? true
        if !isInvalidated && isPopoverVisible && enabled {
            statusStore.vpnStatusService.start()
        } else {
            statusStore.vpnStatusService.stop()
        }
    }

    #if DEBUG
    func setPopoverVisibleForMarketingCapture(_ visible: Bool) {
        guard isMenuShown != visible else { return }
        if visible {
            showPopover()
        } else {
            closePopoverFromContent()
        }
    }
    #endif

    private func setStatusItemLength(_ targetLength: CGFloat) {
        guard !isInvalidated else { return }
        lengthAnimationTimer?.invalidate()

        guard defaults.bool(forKey: PreferenceKeys.animationsEnabled) else {
            statusItem.length = targetLength
            return
        }

        let startLength = statusItem.length
        guard abs(startLength - targetLength) > 0.5 else { return }
        let startDate = Date()
        let duration: TimeInterval = 0.34

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(startDate)
                let progress = min(max(elapsed / duration, 0), 1)
                let eased = 1 - pow(1 - progress, 3)
                self.statusItem.length = startLength + (targetLength - startLength) * eased

                if progress >= 1 {
                    self.statusItem.length = targetLength
                    timer.invalidate()
                    self.lengthAnimationTimer = nil
                }
            }
        }
        lengthAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        if let statusItemMouseMonitor { NSEvent.removeMonitor(statusItemMouseMonitor) }
        statusItemMouseMonitor = nil
        updateVolumeScrollMonitor()
        isPopoverVisible = false
        statusStore.accessoryBatteryService.stop()
        statusStore.vpnStatusService.stop()
        statusStore.nearbyWiFiController.setMenuVisible(false)
        statusStore.networkDiagnostics.cancel()
        cancelHoverClose()
        lengthAnimationTimer?.invalidate()
        lengthAnimationTimer = nil
        popover.performClose(nil)
        glassPanel?.dismiss()
        glassPanel?.setHostedController(nil)
        glassPanel = nil
        popoverContentController = nil
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
        if let accessibilityDisplayObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityDisplayObserver)
            self.accessibilityDisplayObserver = nil
        }
        popoverBackgroundView = nil
        popoverTrackingView?.removeFromSuperview()
        popoverTrackingView = nil
        hostingView?.removeFromSuperview()
        hostingView = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    deinit {
        if let statusItemMouseMonitor { NSEvent.removeMonitor(statusItemMouseMonitor) }
        if let volumeScrollMonitor { NSEvent.removeMonitor(volumeScrollMonitor) }
        pendingHoverClose?.cancel()
        lengthAnimationTimer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
        }
        if let accessibilityDisplayObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityDisplayObserver)
        }
        if !isInvalidated {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

extension MenuBarController {
    private func menuDidShow() {
        statusStore.nearbyWiFiController.setMenuVisible(true)
        isPopoverVisible = true
        updateAccessoryPolling()
        updateVPNMonitoring()
    }

    private func menuWillClose() {
        statusStore.nearbyWiFiController.setMenuVisible(false)
        statusStore.networkDiagnostics.cancel()
        isPopoverVisible = false
        updateVPNMonitoring()
        statusStore.accessoryBatteryService.stop()
    }

    private func menuDidClose() {
        statusStore.nearbyWiFiController.setMenuVisible(false)
        statusStore.networkDiagnostics.cancel()
        isPopoverVisible = false
        updateVPNMonitoring()
        statusStore.accessoryBatteryService.stop()
        perform(hoverInteraction.popoverClosedExternally())
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        guard glassPanel?.isVisible != true else { return }
        menuDidShow()
    }
    func popoverWillClose(_ notification: Notification) {
        guard glassPanel?.isVisible != true else { return }
        menuWillClose()
    }
    func popoverDidClose(_ notification: Notification) {
        // A closing classic popover can finish its animation after glass opens.
        guard glassPanel?.isVisible != true else { return }
        menuDidClose()
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class HoverTrackingContainerView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

}
