import Carbon.HIToolbox
import Foundation

/// Registers two global hotkeys via Carbon's RegisterEventHotKey. The Carbon
/// hotkey API remains the most reliable way to observe modified key presses
/// from any focused application on macOS.
final class HotkeyManager {
    struct Shortcut: Codable, Equatable {
        /// Carbon virtual keycode (e.g. kVK_ANSI_H = 4).
        let keyCode: UInt32
        /// Carbon modifier flags (cmdKey | optionKey | controlKey).
        let modifiers: UInt32
    }

    private static let signature: OSType = 0x4D575752 // 'MWWR'
    private static let moveID: UInt32 = 1
    private static let restoreID: UInt32 = 2

    private var moveRef: EventHotKeyRef?
    private var restoreRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var onMoveToBuiltin: (() -> Void)?
    var onRestoreToExternal: (() -> Void)?

    func registerDefaults() {
        let move = readShortcut(forKey: "shortcut.move") ?? Shortcut(
            keyCode: UInt32(kVK_ANSI_H),
            modifiers: UInt32(cmdKey | optionKey | controlKey)
        )
        let restore = readShortcut(forKey: "shortcut.restore") ?? Shortcut(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: UInt32(cmdKey | optionKey | controlKey)
        )
        install(move: move, restore: restore)
    }

    func update(move: Shortcut, restore: Shortcut) {
        writeShortcut(move, forKey: "shortcut.move")
        writeShortcut(restore, forKey: "shortcut.restore")
        unregisterAll()
        install(move: move, restore: restore)
    }

    func unregisterAll() {
        if let moveRef { UnregisterEventHotKey(moveRef) }
        if let restoreRef { UnregisterEventHotKey(restoreRef) }
        moveRef = nil
        restoreRef = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    // MARK: - Private

    private func install(move: Shortcut, restore: Shortcut) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
                guard let event, let userData else { return noErr }
                var hotkeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                if err != noErr { return err }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    switch hotkeyID.id {
                    case HotkeyManager.moveID: manager.onMoveToBuiltin?()
                    case HotkeyManager.restoreID: manager.onRestoreToExternal?()
                    default: break
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        if status != noErr {
            Log.hotkey.error("InstallEventHandler failed: \(status, privacy: .public)")
            return
        }

        moveRef = register(shortcut: move, id: Self.moveID)
        restoreRef = register(shortcut: restore, id: Self.restoreID)
    }

    private func register(shortcut: Shortcut, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status != noErr {
            Log.hotkey.error("RegisterEventHotKey failed id=\(id, privacy: .public) status=\(status, privacy: .public)")
            return nil
        }
        return ref
    }

    private func readShortcut(forKey key: String) -> Shortcut? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    private func writeShortcut(_ shortcut: Shortcut, forKey key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
