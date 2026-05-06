# MoveWindowsHome

MoveWindowsHome is a macOS menu bar app that moves windows from external monitors back to the MacBook screen with one shortcut.

Use it when a monitor is shared between a MacBook and another computer, such as a PC through a monitor input switch, KVM switch, HDMI switch, USB-C display, or DisplayPort switch. If macOS still thinks the external display is connected, windows can remain on the invisible external desktop. MoveWindowsHome brings those hidden windows home to the built-in display and can restore them to the external monitor later.

## Search keywords

macOS move windows to built-in display, MacBook external monitor window rescue, windows stuck on external display, monitor input switched to PC, KVM switch Mac windows, move all windows to main display, restore window positions, menu bar window manager, Accessibility API window mover, AXUIElement macOS window positioning.

中文关键词: Mac 外接显示器窗口找回, 显示器切换到 PC 后窗口不可见, 一键移动所有窗口到 MacBook 屏幕, KVM 切换 Mac 窗口, macOS 菜单栏窗口工具, 恢复外屏窗口位置。

## What it does

- Moves every normal app window on an external display to the MacBook built-in screen.
- Saves the original external-display position before moving each window.
- Restores saved windows to the external display when that display is available again.
- Runs as a menu bar app with no Dock icon.
- Provides global shortcuts for move and restore.
- Guides the user through the required macOS Accessibility permission.

## Primary use case

```text
External monitor shared by MacBook and PC
-> monitor input is switched from MacBook to PC
-> macOS still keeps the external display active
-> app windows remain on the invisible external desktop
-> press Ctrl + Option + Cmd + H
-> windows move back to the MacBook screen
```

Later, when the external monitor is visible to the Mac again, press `Ctrl + Option + Cmd + R` to restore the saved window positions.

## Default shortcuts

| Action | Shortcut |
| --- | --- |
| Move external-display windows to MacBook screen | `Ctrl + Option + Cmd + H` |
| Restore windows to the external display | `Ctrl + Option + Cmd + R` |

The same actions are also available from the menu bar icon.

## Build and run

Requirements:

- macOS 13 or newer
- Xcode command line tools or Xcode 15+

```sh
swift build
./scripts/build-app.sh
open build/MoveWindowsHome.app
```

## Grant Accessibility permission

MoveWindowsHome needs Accessibility access because macOS only allows trusted apps to move windows that belong to other apps.

1. Launch `MoveWindowsHome.app`.
2. Open `System Settings -> Privacy & Security -> Accessibility` when prompted.
3. Enable `MoveWindowsHome`.
4. Quit and relaunch the app.

## Saved data

The latest window snapshot is stored at:

```text
~/Library/Application Support/MoveWindowsHome/snapshots.json
```

Only the latest move snapshot is kept. Running the move action again replaces the previous snapshot.

## How it works

- `CGWindowListCopyWindowInfo` lists visible app windows.
- `NSScreen` and `CoreGraphics` identify the built-in display and external displays.
- `AXUIElement` writes window position and size through the macOS Accessibility API.
- `_AXUIElementGetWindow` matches Accessibility windows to CoreGraphics window IDs.

## Limitations

- MoveWindowsHome only works on demand, through the shortcut or the menu bar item. Automatic detection is not possible: when a shared monitor is switched to another computer through a KVM, a monitor input switch, or an HDMI switch, macOS still reports the display as connected and emits no event, so no reliable signal is available.
- Only normal top-level application windows are moved. Panels, menus, sheets, and system overlays are ignored.
- Some apps, especially games and a few Java apps, may reject Accessibility position changes.
- Restore first matches by CoreGraphics window ID, then falls back to app bundle ID and window title. A changed window title may reduce restore accuracy.
