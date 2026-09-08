# Omarchy Clipboard Sync

A native Omarchy shell plugin for securely exchanging the current text
clipboard with trusted iPhone and Android devices through KDE Connect.

Clipboard Sync is local-first. Nearby devices communicate directly over the
same local network, even when the Omarchy computer uses Ethernet and the phone
uses Wi-Fi. There is no account, public relay, or plugin-owned clipboard
history.

## Features

- Native Omarchy bar icon and keyboard-accessible popout panel.
- KDE Connect dependency detection and setup guidance.
- Device discovery, pairing, unpairing, selection, and online state.
- Explicit one-click text clipboard sending to one selected device.
- Pause/resume control without unpairing or disabling incoming features.
- Existing `omarchy.clipboard` history integration for received text.
- UTF-8 validation and a 64 KiB payload limit.
- Structured error handling without logging clipboard content.
- Shell IPC actions for keybindings and menu integration.

Version 1 deliberately uses manual outbound sending. Mobile operating systems
restrict background clipboard access, particularly iOS.

## Requirements

- Omarchy 4.x with shell plugin manifest schema 1.
- KDE Connect desktop package.
- `wl-clipboard`, included by Omarchy.
- Official KDE Connect application on the phone.
- A local network where the devices can reach each other.

Install the desktop dependency explicitly:

```bash
omarchy pkg add kdeconnect
```

The plugin never installs packages or changes firewall rules itself.

## Installation

From a published Git repository:

```bash
omarchy plugin add <git-url> --enable
```

For local development, link the checkout into the user plugin directory:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/dimasmufid.clipboard-sync
omarchy-shell shell rescanPlugins
omarchy plugin enable dimasmufid.clipboard-sync --section right
```

Do not edit packaged files under `/usr/share/omarchy/`.

## Use

1. Install KDE Connect on the phone and grant its local-network permission.
2. Keep the phone and Omarchy computer on the same reachable local network.
3. Open Clipboard Sync from the bar and choose Refresh.
4. Select an available phone, choose Pair, and confirm the matching request on
   the phone.
5. Copy text in Omarchy and choose Send.
6. To send in the other direction, use the clipboard/share action supported by
   the phone's KDE Connect app.

Right-clicking the bar icon pauses or resumes outbound sharing. Middle-click
refreshes discovery.

Platform-specific instructions:

- [Android setup](docs/setup-android.md)
- [iPhone setup](docs/setup-ios.md)
- [Troubleshooting](docs/troubleshooting.md)

## IPC

```bash
omarchy-shell dimasmufid.clipboard-sync open
omarchy-shell dimasmufid.clipboard-sync close
omarchy-shell dimasmufid.clipboard-sync refresh
omarchy-shell dimasmufid.clipboard-sync send
omarchy-shell dimasmufid.clipboard-sync pause
omarchy-shell dimasmufid.clipboard-sync resume
omarchy-shell dimasmufid.clipboard-sync status
```

## Test

```bash
./tests/run.sh
```

The suite validates the manifest and adapter behavior with isolated KDE
Connect and clipboard fixtures. Physical mobile tests remain necessary to
verify behavior for a specific Android/iOS and KDE Connect app version.
The latest environment and results are recorded in the
[test report](docs/test-report.md).

## Privacy model

- Manual send is the default.
- Only the selected device is targeted by plugin actions.
- Clipboard content never enters command arguments, environment variables,
  JSON responses, logs, notifications, configuration, or plugin temp files.
- KDE Connect owns pairing keys, encrypted transport, and device identity.
- The plugin does not run a network listener or modify firewall configuration.
- Pairing a device grants it access to content you explicitly send. Unpair lost
  or untrusted devices immediately.

See the complete [v1 specification](ai/specs/clipboard-sync-v1.md) and
[architecture](docs/architecture.md).
