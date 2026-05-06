import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var wrangler: WindowWrangler?
    private var permissionGuard: PermissionGuard?
    private var displayService: DisplayService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let display = DisplayService()
        let window = WindowService()
        let store = SnapshotStore()
        let wrangler = WindowWrangler(
            displayService: display,
            windowService: window,
            snapshotStore: store
        )
        let menu = MenuBarController(wrangler: wrangler)
        let hotkey = HotkeyManager()
        hotkey.onMoveToBuiltin = { [weak menu] in menu?.performMoveToBuiltin() }
        hotkey.onRestoreToExternal = { [weak menu] in menu?.performRestoreToExternal() }
        hotkey.registerDefaults()

        let guard_ = PermissionGuard()
        guard_.promptIfNeeded()

        // Phase 2 hook: display configuration changes are observed but only
        // used to refresh menu state; automatic triggering is not enabled.
        display.onConfigurationChanged = { [weak menu] in menu?.refreshState() }
        display.startObserving()

        self.displayService = display
        self.wrangler = wrangler
        self.menuBarController = menu
        self.hotkeyManager = hotkey
        self.permissionGuard = guard_
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterAll()
        displayService?.stopObserving()
    }
}
