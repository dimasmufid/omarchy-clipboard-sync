# Architecture

## Overview

Clipboard Sync is an Omarchy presentation and policy layer over KDE Connect.
It does not reimplement KDE Connect's network protocol.

```text
iPhone / Android KDE Connect app
              |
       encrypted KDE Connect link
              |
          kdeconnectd
              |
   KDE Connect clipboard integration
              |
       Wayland clipboard
              |
  omarchy.clipboard watcher/history

Omarchy Clipboard Sync panel
              |
   ClipboardSyncService.qml
              |
 scripts/clipboard-sync-adapter
              |
       kdeconnect-cli + wl-paste
```

## Components

### `ClipboardSync.qml`

The Omarchy bar widget and popout panel. It owns visual state, keyboard
navigation, confirmation, selected-device and pause preferences, and IPC.

### `ClipboardSyncService.qml`

The QML state machine. It serializes adapter operations, refreshes device
state, converts responses into UI state, and never stores clipboard content.

### `scripts/clipboard-sync-adapter`

A Python standard-library adapter that provides a stable JSON contract over
the KDE Connect CLI. It validates device IDs, process timeouts, clipboard MIME,
UTF-8, and the 64 KiB limit. External commands always receive argument arrays.

The adapter uses these operations:

```text
doctor
devices
refresh
pair --device-id ID
unpair --device-id ID
send --device-id ID
```

It uses `kdeconnect-cli --send-clipboard`, which instructs KDE Connect to read
the current system clipboard. Clipboard bytes are inspected only in memory for
type/size validation and never appear in adapter output.

### `kdeconnectd`

KDE Connect owns device identity, pairing certificates, LAN discovery,
encrypted transport, protocol compatibility, and incoming clipboard handling.
Restarting the Omarchy shell does not affect device trust.

## Network model

Same LAN means mutual IP reachability. A phone on Wi-Fi and a computer on
Ethernet can connect through the same router. Guest Wi-Fi often blocks clients
from contacting one another.

KDE Connect uses local discovery by default. Tailscale is not required or
configured in v1. A future remote mode can use KDE Connect custom device
addresses because LAN broadcast discovery generally does not cross Tailscale.

## State and persistence

The plugin persists only:

```json
{
  "selectedDeviceId": "...",
  "paused": false,
  "mode": "manual",
  "refreshIntervalSec": 15
}
```

KDE Connect stores pairing material independently. Clipboard content, hashes,
certificates, addresses, command output, and verification values are forbidden
from Omarchy `shell.json`.

## Security boundaries

- Device IDs must match KDE Connect's restricted identifier format.
- Device names are display-only and never used as command selectors.
- The plugin has no network listener and no elevated operation.
- KDE Connect encrypts paired-device traffic.
- Manual mode and a single selected destination reduce accidental disclosure.
- Incoming clipboard values flow through the system clipboard and inherit the
  privacy properties of Wayland, KDE Connect, and the destination applications.

## Known limitation

Validation and `kdeconnect-cli --send-clipboard` are two consecutive
operations. Another application could theoretically replace the clipboard in
that small interval. KDE Connect does not expose a supported CLI operation
that accepts clipboard bytes on stdin. Passing content as a command argument
would create a more serious confidentiality leak, so v1 uses the safer CLI
interface and documents this local race.
