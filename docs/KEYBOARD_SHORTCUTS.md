# Keyboard Shortcuts

## Overview

ProjectStats supports keyboard shortcuts for common actions. Most shortcuts are implemented via hidden SwiftUI buttons with `.keyboardShortcut()` modifiers.

---

## Global Shortcuts

| Shortcut | Action | Scope | Implementation |
|----------|--------|-------|----------------|
| Cmd+Shift+F | Enter Focus Mode | App-wide | Commands menu + TabShellView |
| Cmd+, | Open Settings | App-wide | macOS standard |
| Cmd+Q | Quit App | App-wide | macOS standard |

---

## Tab Navigation

| Shortcut | Action | Implementation |
|----------|--------|----------------|
| Cmd+Shift+T | New Tab | TabShellView keyboardShortcutButtons |
| Cmd+Shift+W | Close Tab | TabShellView keyboardShortcutButtons |
| Cmd+Shift+] | Next Tab | TabShellView keyboardShortcutButtons |
| Cmd+Shift+[ | Previous Tab | TabShellView keyboardShortcutButtons |
| Cmd+Option+1 | Switch to Tab 1 | TabShellView keyboardShortcutButtons |
| Cmd+Option+2 | Switch to Tab 2 | TabShellView keyboardShortcutButtons |
| Cmd+Option+3 | Switch to Tab 3 | TabShellView keyboardShortcutButtons |
| Cmd+Option+4 | Switch to Tab 4 | TabShellView keyboardShortcutButtons |
| Cmd+Option+5 | Switch to Tab 5 | TabShellView keyboardShortcutButtons |
| Cmd+Option+6 | Switch to Tab 6 | TabShellView keyboardShortcutButtons |
| Cmd+Option+7 | Switch to Tab 7 | TabShellView keyboardShortcutButtons |
| Cmd+Option+8 | Switch to Tab 8 | TabShellView keyboardShortcutButtons |
| Cmd+Option+9 | Switch to Tab 9 | TabShellView keyboardShortcutButtons |

---

## Command Palette

| Shortcut | Action | Implementation |
|----------|--------|----------------|
| Cmd+K | Open Command Palette | TabShellView keyboardShortcutButtons |

### Command Palette Commands

| Command | Icon | Shortcut (display) |
|---------|------|-------------------|
| New Terminal Tab | terminal | ⌘T |
| Commit Changes | arrow.up.circle | ⌘⇧C |
| Refresh Project Stats | arrow.clockwise | ⌘R |
| Open Settings | gear | ⌘, |

---

## Focus Mode

| Shortcut | Action | Implementation |
|----------|--------|----------------|
| Escape | Exit Focus Mode | Sheet dismissal |

---

## Terminal (SwiftTerm)

SwiftTerm handles standard terminal shortcuts:

| Shortcut | Action |
|----------|--------|
| Cmd+C | Copy (when text selected) / Interrupt (otherwise) |
| Cmd+V | Paste |
| Ctrl+C | Send interrupt signal |
| Ctrl+D | Send EOF |
| Ctrl+Z | Suspend |
| Up Arrow | Previous command (shell history) |
| Down Arrow | Next command (shell history) |

---

## Implementation Details

### TabShellView Hidden Buttons

```swift
private var keyboardShortcutButtons: some View {
    Group {
        Button("") { tabManager.newTab() }
            .keyboardShortcut("t", modifiers: [.command, .shift])

        Button("") {
            if let id = tabManager.activeTab?.id,
               tabManager.activeTab?.isCloseable == true {
                tabManager.closeTab(id)
            }
        }
        .keyboardShortcut("w", modifiers: [.command, .shift])

        Button("") { tabManager.nextTab() }
            .keyboardShortcut("]", modifiers: [.command, .shift])

        Button("") { tabManager.previousTab() }
            .keyboardShortcut("[", modifiers: [.command, .shift])

        // Tab switching
        Button("") { tabManager.selectTab(at: 0) }
            .keyboardShortcut("1", modifiers: [.command, .option])
        // ... buttons for 2-9

        Button("") { showCommandPalette.toggle() }
            .keyboardShortcut("k", modifiers: [.command])
    }
    .opacity(0)
    .frame(width: 0, height: 0)
}
```

### Commands Menu (Focus Mode)

```swift
.commands {
    CommandGroup(after: .windowArrangement) {
        Button("Enter Focus Mode") {
            NotificationCenter.default.post(name: .enterFocusMode, object: nil)
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
    }
}
```

---

## Modifier Key Reference

| Symbol | Key |
|--------|-----|
| ⌘ | Command |
| ⇧ | Shift |
| ⌥ | Option/Alt |
| ⌃ | Control |

---

## Notes

### Why Cmd+Shift instead of Cmd?

Simple Cmd+T and Cmd+W are reserved by the system or could conflict with text editing. Using Cmd+Shift avoids conflicts.

### Why Cmd+Option for Tab Numbers?

Cmd+1-9 often used for other purposes in macOS apps. Cmd+Option ensures no conflicts.

### Focus Mode Hotkey

Cmd+Shift+F is registered both in the Commands menu (works app-wide) and posted via NotificationCenter. This allows it to work from any context.

---

## Adding New Shortcuts

1. Add hidden button in appropriate view:
```swift
Button("") { action() }
    .keyboardShortcut("x", modifiers: [.command])
    .opacity(0)
    .frame(width: 0, height: 0)
```

2. Or add to Commands menu in App:
```swift
.commands {
    CommandGroup(after: .windowArrangement) {
        Button("Action Name") { action() }
            .keyboardShortcut("x", modifiers: [.command])
    }
}
```

3. Document in this file.
