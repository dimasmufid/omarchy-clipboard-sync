---
title: Omarchy Clipboard Sync v1
status: Implemented — physical mobile validation pending
version: 0.1.0
last_updated: 2026-09-08
owner: Dimas Mufid
plugin_id: dimasmufid.clipboard-sync
---

# Omarchy Clipboard Sync v1

## 1. Summary

Omarchy Clipboard Sync adds a native Omarchy shell experience for securely
exchanging the current text clipboard with a trusted iPhone or Android device.
The first release uses KDE Connect for device discovery, pairing, encryption,
transport, and mobile applications. The Omarchy plugin owns the desktop UI,
dependency checks, device selection, explicit send controls, pause state, and
diagnostics.

The default transport is a direct connection on the same local network. The
computer may be connected by Ethernet while the phone is connected by Wi-Fi;
they do not have to use the same radio, only a network where each device can
reach the other. Tailscale support is a later fallback for devices on different
networks.

Version 1 intentionally does not recreate Apple's Universal Clipboard
protocol, ship custom mobile applications, or promise silent background
clipboard monitoring on iOS.

## 2. Decision summary

| Area | v1 decision |
|---|---|
| Desktop environment | Omarchy 4 shell on Hyprland/Wayland |
| Plugin type | Third-party Omarchy `bar-widget` with a popout panel |
| Transport | KDE Connect LAN transport |
| Pairing and encryption | KDE Connect-managed |
| Mobile clients | Official KDE Connect Android and iOS applications |
| Content type | UTF-8 plain text only |
| Outbound default | Manual send |
| Inbound behavior | KDE Connect applies the clipboard; Omarchy history observes it |
| Automatic outbound | Opt-in and only where the mobile/desktop platform supports it reliably |
| Remote networks | Deferred; Tailscale/custom device address in a later milestone |
| Clipboard history sync | Out of scope |
| Public cloud or relay | Out of scope |

## 3. Problem statement

Omarchy can already watch and update the local Wayland clipboard and has a
native clipboard history overlay. It does not provide a cohesive phone-pairing
or clipboard-sync experience. Users can share clipboard content through
LocalSend, but that is a file-sharing flow and is not the same as selecting a
trusted phone and making the text available in its clipboard.

The plugin should make the common path short:

1. Pair a phone once.
2. Copy text on Omarchy.
3. Open the Clipboard Sync panel or invoke a shortcut.
4. Send the current clipboard to the selected phone.
5. Paste on the phone, subject to its operating-system restrictions.

The reverse flow should place text received by KDE Connect into the Wayland
clipboard. Omarchy's existing clipboard manager should record it through its
normal `wl-paste --watch` path rather than through a second history store.

## 4. Goals

### 4.1 Product goals

- Feel like a native part of Omarchy rather than a separate KDE desktop app.
- Make dependency state, connectivity, pairing, and sync state understandable
  without opening a terminal.
- Transfer the current text clipboard to one selected trusted phone with one
  explicit action.
- Receive text from a paired phone through KDE Connect and expose it through
  the normal Wayland clipboard.
- Prefer direct local-network transfer for low latency and no server cost.
- Avoid logging, persisting, or displaying clipboard content unnecessarily.
- Degrade honestly on Android and iOS when the operating system requires a
  foreground app or user gesture.
- Keep the transport behind an adapter so KDE Connect CLI or D-Bus changes do
  not spread through QML components.

### 4.2 Engineering goals

- Use the Omarchy plugin manifest and `BarWidget`/panel contracts.
- Do not modify packaged files under `/usr/share/omarchy/`.
- Do not implement or parse raw KDE Connect network packets in v1.
- Use argument arrays for all process execution; never concatenate a device
  name, device ID, clipboard value, or remote address into a shell command.
- Keep pairing keys and KDE Connect identity in KDE Connect's own storage.
- Make the adapter testable without a real phone by using command fixtures or
  a fake `kdeconnect-cli` executable.
- Avoid a second background daemon until a demonstrated requirement cannot be
  met through `kdeconnectd`, KDE Connect D-Bus, and the shell plugin.

## 5. Non-goals

- Joining Apple's private Handoff or Universal Clipboard trust system.
- Silent, continuous background clipboard reads on iPhone.
- Circumventing Android clipboard privacy restrictions with accessibility
  abuse, root, ADB privileges, or a deceptive input method.
- Synchronizing a complete clipboard history between devices.
- Supporting images, videos, files, HTML, RTF, or arbitrary MIME types in v1.
- Building or hosting an internet relay service.
- Creating Omarchy, KDE, Apple, Google, or cloud accounts.
- Automatically installing packages or modifying firewall rules with elevated
  privileges from the plugin.
- Replacing `omarchy.clipboard` or maintaining a duplicate clipboard history.
- Sending clipboard contents to every paired device by default.
- Guaranteeing operation on public Wi-Fi networks that isolate clients.

## 6. Terminology

| Term | Meaning |
|---|---|
| Local device | The Omarchy computer running this plugin |
| Remote device | An iPhone, Android phone, tablet, or another paired KDE Connect peer |
| Same LAN | Both devices are mutually reachable on the same local IP network |
| Reachable | KDE Connect currently has a live connection to the device |
| Paired | Both KDE Connect peers have explicitly established trust |
| Selected device | The single remote target used by Send now |
| Manual mode | Clipboard content leaves Omarchy only after explicit user action |
| Automatic mode | Eligible local clipboard changes are forwarded without another action |
| Paused | No plugin-initiated outbound transfer is allowed |
| Sensitive content | Clipboard data that may contain passwords, tokens, recovery codes, or personal data |

## 7. Platform constraints

### 7.1 Omarchy and Wayland

- Omarchy 4 hosts third-party plugins inside the long-running
  `omarchy-shell` Quickshell process.
- Third-party plugin code is unsandboxed. The plugin must be minimal and must
  never accept untrusted data as executable code.
- The existing `omarchy.clipboard` plugin monitors text and image changes with
  `wl-paste --watch` and maintains local history.
- Received KDE Connect text should enter the normal Wayland clipboard. If
  `kdeconnectd` does this successfully under native Wayland, no additional
  `wl-copy` adapter is needed.
- QML settings may contain non-secret preferences only. Clipboard values,
  pairing keys, and device certificates must never be written to `shell.json`.

### 7.2 KDE Connect

- KDE Connect is the authority for network discovery, pairing, device trust,
  transport encryption, and clipboard packets.
- KDE Connect peers must be paired before clipboard data is exchanged.
- Local discovery normally uses LAN broadcast/mDNS. Client-isolated Wi-Fi,
  restrictive firewalls, VLAN boundaries, and VPN policy can prevent it.
- The current CLI exposes device listing, refresh, pairing, unpairing, and
  `--send-clipboard`. Exact CLI spelling and D-Bus signatures must be verified
  against the installed Arch package before implementation.
- Human-oriented CLI output may be localized. Machine-readable or
  identifier-only output must be used when available; otherwise parsing lives
  exclusively in the adapter with fixtures for every supported format.
- KDE Connect's documented clipboard packet contains text content, and its
  connection-time variant includes a timestamp. The plugin must not invent a
  private packet extension in v1.

### 7.3 Android

- Android 10 and later prevent an ordinary background app from reading the
  clipboard unless it is focused or is the default input method.
- Receiving content and setting the Android clipboard depends on the Android
  version, vendor behavior, KDE Connect version, and enabled KDE Connect
  plugin permissions.
- The UI and documentation must say whether the tested behavior is automatic,
  notification-driven, foreground-only, or manual.
- Automatic outbound phone-to-Omarchy sync is not a v1 acceptance requirement.

### 7.4 iOS

- A normal iOS application does not receive a general background wake-up for
  every clipboard change.
- Reading clipboard content from another application may require clear user
  intent and may show an iOS paste-access prompt.
- The expected iPhone experience is KDE Connect in the foreground or an
  explicit app/share/clipboard action.
- Documentation and UI must not describe iPhone behavior as identical to
  Apple Universal Clipboard.

## 8. User stories

### 8.1 Setup

- As an Omarchy user, I can see when KDE Connect is missing and receive a safe
  installation instruction instead of a broken button.
- As an Omarchy user, I can refresh discovery and see nearby devices.
- As an Omarchy user, I can request pairing with a visible phone and confirm
  that the verification code matches on both devices.
- As an Omarchy user, I can tell whether a device is paired, reachable, or
  offline.

### 8.2 Daily use

- As an Omarchy user, I can send my current text clipboard to my selected
  phone with one panel action.
- As an Omarchy user, I receive immediate feedback that sending started and a
  clear success or failure result.
- As an Omarchy user, text sent from my phone becomes available to paste in
  Omarchy and appears naturally in Omarchy's existing clipboard history.
- As an Omarchy user, I can pause outbound clipboard sharing without unpairing
  my phone.
- As an Omarchy user, the last selected paired device remains selected after a
  shell restart.

### 8.3 Recovery and privacy

- As an Omarchy user, I can unpair a lost phone.
- As an Omarchy user, I can see why discovery or sending failed without the
  diagnostic output exposing my clipboard content.
- As an Omarchy user, I can keep outbound syncing manual, which is the default.
- As an Omarchy user, I am warned before enabling automatic outbound sync.

## 9. Functional requirements

Requirement keywords MUST, SHOULD, and MAY are normative.

### 9.1 Dependency and lifecycle

- **FR-001:** The plugin MUST detect whether `kdeconnect-cli` is executable.
- **FR-002:** The plugin MUST distinguish `missing`, `starting`, `ready`, and
  `error` dependency states.
- **FR-003:** The plugin MUST NOT automatically install KDE Connect.
- **FR-004:** When KDE Connect is missing, the panel SHOULD show the command
  `omarchy pkg add kdeconnect` with a copy action. The user runs it explicitly.
- **FR-005:** The plugin MUST work after `omarchy-shell` hot reload without
  spawning duplicate long-running watchers.
- **FR-006:** If `kdeconnectd` is not running, the plugin MAY trigger it through
  the supported KDE Connect activation path without privilege escalation.
- **FR-007:** Process timeouts and non-zero exits MUST transition to a visible
  error state rather than leaving the UI indefinitely busy.

### 9.2 Discovery and device state

- **FR-010:** The panel MUST list devices using stable device IDs as identity.
- **FR-011:** Each row MUST show the sanitized device name, device type when
  available, paired state, reachable state, and selected state.
- **FR-012:** The UI MUST NOT use a device name as a command-line selector when
  a stable device ID is available.
- **FR-013:** Refresh MUST ask KDE Connect to rescan and then update the list.
- **FR-014:** The first discovery result SHOULD appear within 5 seconds on a
  functioning same-LAN setup; the UI MUST allow KDE Connect's longer discovery
  window without freezing.
- **FR-015:** Device polling MUST stop or slow down while the widget is not
  loaded, and MUST never overlap the previous poll.
- **FR-016:** A device that disappears MUST become offline without being
  silently unpaired or removed.
- **FR-017:** v1 MUST support one selected target device at a time.
- **FR-018:** Selection MUST persist by device ID, not display name.

### 9.3 Pairing

- **FR-020:** Pairing MUST only be available for an unpaired reachable device.
- **FR-021:** The panel MUST explain that the user must verify and accept the
  request on the other device.
- **FR-022:** Pairing requests MUST expose pending, accepted, rejected, and
  timed-out outcomes.
- **FR-023:** A pairing timeout MUST NOT be reported as rejection.
- **FR-024:** The plugin MUST delegate verification keys, certificates, and
  trust persistence to KDE Connect.
- **FR-025:** Unpair MUST require confirmation naming the exact device.
- **FR-026:** Unpairing the selected device MUST clear the selection or select
  another paired reachable device deterministically.
- **FR-027:** Incoming pairing acceptance MAY be deferred if KDE Connect does
  not expose a safe event-driven interface usable by Quickshell in v1. The
  outgoing desktop-to-phone pairing flow is required.

### 9.4 Clipboard send

- **FR-030:** Manual Send now MUST target only the selected paired reachable
  device.
- **FR-031:** Send now MUST be disabled while paused, when no device is
  selected, or when the selected device is offline/unpaired.
- **FR-032:** The plugin MUST read the current clipboard only after the user
  invokes Send now in manual mode.
- **FR-033:** v1 MUST accept UTF-8 plain text only.
- **FR-034:** An empty clipboard MUST produce a non-error `Nothing to send`
  result.
- **FR-035:** Text larger than 64 KiB encoded as UTF-8 MUST be rejected before
  transport with a size-specific message.
- **FR-036:** Clipboard content MUST be passed through the clipboard facility
  expected by KDE Connect; it MUST NOT be placed in shell command text,
  command-line arguments, environment variables, logs, notifications, or
  temporary files owned by the plugin.
- **FR-037:** A send action MUST show immediate busy feedback and resolve to
  success, offline, permission, timeout, or generic error.
- **FR-038:** Repeated clicks while a send is active MUST NOT start duplicate
  sends.
- **FR-039:** The plugin MUST NOT claim the remote clipboard was updated if the
  local KDE Connect command only confirms queueing. User-facing wording should
  use `Sent to KDE Connect` unless delivery acknowledgment is available.
- **FR-040:** The plugin SHOULD expose a shell IPC action for manual send so an
  Omarchy keybinding or menu entry can trigger the same validated path.

### 9.5 Clipboard receive

- **FR-050:** v1 MUST first rely on KDE Connect's clipboard plugin to apply
  incoming text to the local Wayland clipboard.
- **FR-051:** The implementation MUST verify this behavior under an Omarchy
  Wayland session before introducing another service.
- **FR-052:** Text received into Wayland SHOULD be captured by the existing
  `omarchy.clipboard` history without direct history-file writes.
- **FR-053:** The plugin MUST NOT create its own clipboard-history database.
- **FR-054:** If KDE Connect cannot set the Wayland clipboard reliably, a
  fallback adapter MAY call `wl-copy`, but only after a separate design review
  covering event delivery, content transfer, ownership lifetime, and loop
  prevention.
- **FR-055:** The plugin MUST NOT send an automatic response merely because a
  received value changed the local clipboard.

### 9.6 Pause and sync mode

- **FR-060:** The default outbound mode MUST be manual.
- **FR-061:** Pause MUST block plugin-initiated outbound transfers immediately.
- **FR-062:** Pause MUST NOT unpair devices or disable unrelated KDE Connect
  plugins.
- **FR-063:** The paused state MUST be visible in the bar and panel.
- **FR-064:** Automatic outbound mode MUST be hidden or marked experimental
  until end-to-end behavior is validated on physical Android and iOS devices.
- **FR-065:** Enabling automatic outbound MUST show a privacy warning that
  clipboard data may include passwords, tokens, and personal information.
- **FR-066:** Automatic outbound MUST be separately configurable for each
  selected device if it is implemented.

### 9.7 Tailscale and non-LAN connectivity

- **FR-070:** Same-LAN transfer MUST work without Tailscale.
- **FR-071:** Tailscale MUST NOT be a v1 dependency.
- **FR-072:** A later remote mode SHOULD configure a KDE Connect custom device
  address because multicast/broadcast discovery normally does not cross the
  tailnet.
- **FR-073:** Adding a custom device address MUST be explicit and preserve all
  existing KDE Connect configuration values.
- **FR-074:** The plugin MUST NOT edit KDE Connect configuration in v1.
- **FR-075:** The panel SHOULD explain that public or guest Wi-Fi client
  isolation can prevent same-LAN discovery.

### 9.8 Diagnostics

- **FR-080:** Diagnostics MUST report plugin version, dependency availability,
  KDE Connect version, daemon reachability, device counts, and last operation
  category.
- **FR-081:** Diagnostics MUST NOT contain clipboard content, clipboard hashes,
  pairing secrets, certificate bodies, or raw device packets.
- **FR-082:** Device IDs SHOULD be redacted in copied diagnostics, retaining
  only a short suffix when correlation is necessary.
- **FR-083:** The panel MUST offer retry for recoverable errors.
- **FR-084:** Firewall guidance MAY identify KDE Connect's documented port
  range, but the plugin MUST NOT change the firewall automatically.
- **FR-085:** External process stderr MUST be sanitized before display and
  length-limited.

## 10. UX specification

### 10.1 Bar widget states

| Priority | State | Suggested icon treatment | Tooltip/label |
|---:|---|---|---|
| 1 | Error | Urgent color | Clipboard Sync error |
| 2 | Missing dependency | Dim/broken-link icon | Install KDE Connect |
| 3 | Paused | Dim/pause badge | Clipboard Sync paused |
| 4 | Sending/pairing | Animated or progress treatment | Sending… / Pairing… |
| 5 | Selected device online | Normal/accent treatment | Connected to `<device>` |
| 6 | Paired devices offline | Dim treatment | Phone offline |
| 7 | No paired devices | Neutral treatment | Pair a phone |
| 8 | Checking | Neutral/progress treatment | Checking… |

Only status text may appear in the bar. Clipboard content and a content
preview MUST never appear there.

### 10.2 Panel layout

```text
+--------------------------------------------------+
| Clipboard Sync                         [Refresh] |
| Connected locally to "Dimas's iPhone"           |
|                                                  |
| [ Send clipboard ]              [ Pause ]        |
|                                                  |
| Devices                                          |
|  ● Dimas's iPhone        Paired · Selected       |
|  ○ Pixel 10               Offline                 |
|  + Pair another device                           |
|                                                  |
| Mode                                             |
|  Manual send                                      |
|                                                  |
| Privacy: clipboard text is sent only when you    |
| press Send clipboard.                            |
|                                           [⋯]    |
+--------------------------------------------------+
```

The actual component must follow Omarchy's existing spacing, typography,
selection, keyboard-navigation, and popout behavior rather than introducing a
new visual language.

### 10.3 First-run flow

1. Widget loads and checks `kdeconnect-cli`.
2. If missing, panel shows an explanation and a copyable install command.
3. After installation, Retry rechecks without requiring a shell restart.
4. If no device is paired, panel starts or refreshes discovery.
5. User chooses a visible phone and selects Pair.
6. Panel instructs the user to confirm the matching verification value on the
   phone. KDE Connect remains the source of truth for this value.
7. On success, the phone becomes selected if no other selected device exists.
8. Panel displays Manual mode and the Send clipboard action.

### 10.4 Manual send flow

1. User copies text in any Wayland application.
2. User opens the panel and presses Send clipboard, or invokes the plugin IPC
   action from a future keybinding.
3. Plugin verifies not paused, selected device paired/reachable, MIME is text,
   clipboard non-empty, and encoded size at most 64 KiB.
4. Plugin invokes the adapter/KDE Connect send action once.
5. Button becomes busy immediately.
6. Success uses a short non-intrusive confirmation. Failure stays visible in
   the panel and offers Retry.

### 10.5 Receive flow

1. User invokes KDE Connect's supported clipboard/share action on the phone.
2. KDE Connect transfers the text over its authenticated channel.
3. `kdeconnectd` updates the local Wayland clipboard.
4. `omarchy.clipboard` observes the normal clipboard change.
5. User can paste normally or open Omarchy clipboard history.

No additional `Received clipboard` notification is required by default,
because frequent notifications would make clipboard use noisy. An optional
notification may be considered after user testing.

### 10.6 Error copy

Errors should state the condition and a next action:

| Condition | Message | Action |
|---|---|---|
| KDE Connect missing | KDE Connect is required to connect your phone. | Copy install command |
| No devices | No phones found on this network. | Refresh / Help |
| Guest Wi-Fi isolation | Devices may be blocked from seeing each other. | Network help |
| Device offline | `<device>` is currently offline. | Retry |
| Unpaired | Pair `<device>` before sending clipboard text. | Pair |
| Empty clipboard | There is no text to send. | Dismiss |
| Unsupported MIME | Version 1 can send plain text only. | Dismiss |
| Oversized text | Clipboard text is larger than 64 KiB. | Dismiss |
| Timeout | KDE Connect did not respond in time. | Retry |
| iPhone limitation | Open KDE Connect on iPhone to complete this action. | Dismiss |

## 11. Technical architecture

### 11.1 Components

```text
Omarchy bar
  └─ ClipboardSync.qml
       └─ ClipboardSyncPanel.qml
            └─ ClipboardSyncService.qml
                 └─ scripts/clipboard-sync-adapter
                      ├─ kdeconnect-cli
                      ├─ KDE Connect D-Bus (when required)
                      └─ wl-paste (manual validation/read only)

kdeconnectd
  ├─ LAN discovery and encrypted device link
  ├─ pairing/trust
  └─ clipboard plugin
       └─ Wayland clipboard
            └─ existing omarchy.clipboard watcher/history
```

### 11.2 Responsibility boundary

`kdeconnectd` owns:

- network identity;
- certificate and pairing state;
- peer discovery and reachability;
- encrypted transport;
- KDE Connect clipboard protocol;
- applying received clipboard content where supported.

The adapter owns:

- stable, JSON-formatted operations for QML;
- timeouts and exit-code normalization;
- localized-output containment;
- dependency/version checks;
- requesting discovery, pairing, unpairing, and send;
- validating that a stable device ID is passed to state-changing commands.

The QML plugin owns:

- rendering state;
- user interaction and confirmation;
- selected-device preference;
- pause/manual-mode preference;
- scheduling non-overlapping state refreshes;
- invoking adapter operations without shell interpolation.

### 11.3 Adapter contract

The adapter SHOULD be a small executable at
`scripts/clipboard-sync-adapter`. It MUST write exactly one JSON object to
stdout and human-readable diagnostics to stderr. Clipboard content must never
be written to either stream.

Proposed commands:

```text
clipboard-sync-adapter doctor
clipboard-sync-adapter devices
clipboard-sync-adapter refresh
clipboard-sync-adapter pair --device-id <id>
clipboard-sync-adapter unpair --device-id <id>
clipboard-sync-adapter send --device-id <id>
```

Common response envelope:

```json
{
  "ok": true,
  "operation": "devices",
  "error": null,
  "data": {},
  "observedAt": "2026-09-08T12:00:00Z"
}
```

Error envelope:

```json
{
  "ok": false,
  "operation": "send",
  "error": {
    "code": "DEVICE_OFFLINE",
    "message": "The selected device is offline.",
    "retryable": true
  },
  "data": null,
  "observedAt": "2026-09-08T12:00:00Z"
}
```

Device representation:

```json
{
  "id": "stable-kde-connect-device-id",
  "name": "Dimas iPhone",
  "type": "phone",
  "paired": true,
  "reachable": true,
  "clipboardCapable": true
}
```

Required error codes:

```text
DEPENDENCY_MISSING
DAEMON_UNAVAILABLE
INVALID_ARGUMENT
DEVICE_NOT_FOUND
DEVICE_OFFLINE
DEVICE_UNPAIRED
PAIR_REJECTED
PAIR_TIMEOUT
CLIPBOARD_EMPTY
CLIPBOARD_NOT_TEXT
CLIPBOARD_TOO_LARGE
OPERATION_BUSY
OPERATION_TIMEOUT
PERMISSION_DENIED
UNSUPPORTED_VERSION
INTERNAL_ERROR
```

Exit-code policy:

| Exit code | Meaning |
|---:|---|
| 0 | JSON response produced; operation completed successfully |
| 2 | Invalid adapter invocation |
| 3 | Dependency or compatibility failure |
| 4 | Device/pairing/connectivity failure |
| 5 | Clipboard validation failure |
| 6 | Timeout |
| 10 | Unexpected internal failure |

QML MUST still parse the JSON error code; the process exit code is only a
coarse category.

### 11.4 KDE Connect interface strategy

1. Prefer stable D-Bus properties/signals for structured device state when
   they are present and documented by the installed version.
2. Use `kdeconnect-cli` for explicit state-changing actions that it officially
   supports, including refresh, pair, unpair, and send clipboard.
3. Use identifier-only CLI formats and `LC_ALL=C` if D-Bus is unavailable.
4. Never parse translated prose to decide whether a device is paired or
   reachable when a structured property exists.
5. Put all version-specific behavior in the adapter.
6. Record the minimum supported KDE Connect version after testing the current
   Arch package; do not guess it in the manifest.

Illustrative commands, to be verified during implementation:

```bash
kdeconnect-cli --refresh
kdeconnect-cli --list-available --id-name-only
kdeconnect-cli --device DEVICE_ID --pair
kdeconnect-cli --device DEVICE_ID --unpair
kdeconnect-cli --device DEVICE_ID --send-clipboard
```

These examples are not a license to interpolate `DEVICE_ID` into a shell
string. The implementation must pass it as a distinct argv element.

### 11.5 State model

Top-level service state:

```text
initializing
  ├─ dependency_missing
  ├─ daemon_unavailable
  ├─ ready_no_devices
  ├─ ready_offline
  ├─ ready_connected
  └─ error
```

Orthogonal flags:

```text
paused: boolean
operation: idle | refreshing | pairing | unpairing | sending
mode: manual | automatic-experimental
selectedDeviceId: string | null
```

State transitions MUST be based on stable IDs and completed adapter responses.
Late responses from an older refresh generation MUST be ignored.

### 11.6 Settings and persistence

Permitted plugin settings in `shell.json`:

```json
{
  "id": "dimasmufid.clipboard-sync",
  "refreshIntervalSec": 15,
  "selectedDeviceId": "...",
  "paused": false,
  "mode": "manual"
}
```

Forbidden in `shell.json`:

- clipboard content or previews;
- clipboard hashes;
- device certificates;
- KDE Connect private keys;
- pairing verification values;
- IP addresses unless a later explicit remote-mode specification allows them;
- raw command output.

KDE Connect remains the sole owner of pairing and trust persistence.

### 11.7 Concurrency and timeouts

- Only one state-changing operation may run at a time.
- Device refresh MAY run while the panel is closed, but refreshes MUST not
  overlap.
- A manual user refresh may cancel or supersede a scheduled refresh.
- Each response carries an internal generation number in QML; stale results
  cannot overwrite newer state.
- Suggested initial timeouts:
  - dependency/version check: 2 seconds;
  - device-list query: 3 seconds;
  - refresh request: 5 seconds for command completion, followed by polling;
  - clipboard send: 5 seconds;
  - pairing: KDE Connect's supported pairing window, expected around 30 seconds.
- Timeouts must terminate only the child command started by the plugin, never
  `kdeconnectd` globally.

## 12. Security and privacy specification

### 12.1 Threat model

The design considers:

- an untrusted device on the same Wi-Fi attempting to pair;
- a malicious device name or ID attempting command injection;
- accidental copying of passwords, API keys, recovery codes, or one-time codes;
- a lost but still-paired phone;
- guest Wi-Fi observation or manipulation;
- sensitive clipboard content leaking through logs, process arguments,
  temporary files, crash reports, notifications, or config;
- denial of service through huge clipboard values or repeated operations;
- stale asynchronous results causing content to be sent to the wrong device.

### 12.2 Required controls

- Pairing requires explicit confirmation through KDE Connect.
- State-changing commands use stable IDs and argv arrays.
- Manual outbound is the default.
- Clipboard values never appear in process arguments or logs.
- v1 has a 64 KiB UTF-8 text limit.
- Only one device receives a manual send.
- Pausing blocks outbound actions visibly.
- Unpairing requires confirmation.
- Diagnostics redact device identity and exclude clipboard-derived values.
- No network listener, HTTP API, or public relay is added by this plugin.
- No privileged commands are executed by QML or the adapter.
- No automatic firewall changes are made.

### 12.3 Known residual risks

- KDE Connect and its mobile apps necessarily receive the transferred content.
- Once placed into the destination system clipboard, other applications may be
  able to read it according to that operating system's rules.
- The plugin generally cannot determine which source application created a
  Wayland clipboard value, so it cannot reliably exclude password managers.
- Pairing the wrong device exposes future explicitly sent clipboard text to
  that device until it is unpaired.
- Manual mode reduces accidental disclosure but cannot identify whether the
  user-selected content is sensitive.

## 13. Performance and reliability requirements

- **NFR-001:** Opening the already-loaded panel SHOULD provide visible feedback
  within 100 ms; network results may update asynchronously.
- **NFR-002:** A manual send on a healthy same-LAN connection SHOULD complete
  its local KDE Connect operation within 2 seconds for a 1 KiB text payload.
- **NFR-003:** The widget MUST remain responsive while commands run.
- **NFR-004:** No polling command may remain running after the plugin is
  unloaded.
- **NFR-005:** Scheduled discovery/status checks SHOULD consume negligible CPU
  while idle and default to no more than one call every 15 seconds.
- **NFR-006:** Restarting `omarchy-shell` MUST not unpair devices or lose KDE
  Connect trust.
- **NFR-007:** Restarting `kdeconnectd` MUST recover on the next refresh without
  restarting the whole desktop session.
- **NFR-008:** Unexpected adapter output MUST produce a bounded error, not a QML
  exception loop.
- **NFR-009:** Device names up to the KDE Connect protocol limit and non-ASCII
  names MUST render safely.

## 14. Accessibility and keyboard behavior

- Every actionable row must be reachable through Omarchy's panel keyboard
  navigation conventions.
- Focus order should be Refresh, Send, Pause, device rows, mode, overflow/help.
- Pair, unpair, and Send must work without a mouse.
- State must not be communicated by color alone.
- Busy states must prevent duplicate activation while retaining a readable
  label.
- Dynamic status changes should not unexpectedly move focus.
- Device names must be elided visually without changing the accessible label.

## 15. File and module plan

Target project structure:

```text
clipboard-sync/
├── manifest.json
├── ClipboardSync.qml
├── ClipboardSyncPanel.qml
├── ClipboardSyncService.qml
├── components/
│   ├── DeviceRow.qml
│   ├── EmptyState.qml
│   └── StatusBadge.qml
├── scripts/
│   └── clipboard-sync-adapter
├── tests/
│   ├── adapter/
│   ├── fixtures/
│   └── manual/
├── ai/specs/
│   └── clipboard-sync-v1.md
├── docs/
│   ├── architecture.md
│   ├── setup-android.md
│   ├── setup-ios.md
│   └── troubleshooting.md
├── README.md
└── LICENSE
```

The implementation may split QML differently when following an established
Omarchy first-party panel pattern, but responsibilities must remain separated
between presentation, state/service logic, and external-process adaptation.

## 16. Implementation plan

### Phase 0 — Specification and compatibility spike

- Finalize this specification.
- Install the current Arch `kdeconnect` package explicitly outside the plugin.
- Record `kdeconnect-cli --help`, version, D-Bus objects, and Wayland behavior.
- Pair one Android device and one iPhone where available.
- Confirm which clipboard directions work in foreground and background.
- Confirm whether received text reaches `wl-paste` and Omarchy history.
- Decide whether D-Bus, CLI, or a hybrid is the stable adapter backend.

Exit criteria:

- No unresolved question blocks the manual text-send path.
- Exact commands and minimum supported KDE Connect version are documented.
- At least one physical phone can pair with Omarchy on the same LAN.

### Phase 1 — Adapter foundation

- Implement `doctor`, `devices`, and `refresh`.
- Normalize all output to the JSON envelope.
- Add hard timeouts and deterministic error codes.
- Add fake CLI fixtures for missing dependency, no devices, online paired,
  online unpaired, offline paired, malformed output, and timeout.
- Ensure clipboard content is not accessed by these operations.

Exit criteria:

- Adapter tests pass without KDE Connect installed.
- Real-device output maps to the same device schema.
- Malicious device names cannot alter process execution.

### Phase 2 — Native panel and device selection

- Replace the placeholder click notification with an Omarchy popout panel.
- Implement bar state mapping and keyboard navigation.
- Render device states and selection.
- Persist only stable selected device ID and non-sensitive preferences.
- Provide dependency-missing and no-device states.

Exit criteria:

- Panel works in horizontal and vertical bars.
- Shell hot reload does not duplicate timers or commands.
- Selecting a device survives shell restart.

### Phase 3 — Pairing and unpairing

- Implement outgoing pairing request and status updates.
- Surface accept/reject/timeout accurately.
- Implement confirmed unpair.
- Determine whether incoming pairing is feasible in the same release.

Exit criteria:

- A fresh Android or iPhone can be paired from the panel-assisted flow.
- Rejected and timed-out requests have different UI states.
- Unpairing removes trust through KDE Connect and clears stale selection.

### Phase 4 — Manual text send

- Implement clipboard type, empty, and 64 KiB checks.
- Add `send` adapter operation using KDE Connect's supported clipboard action.
- Add busy, success, offline, and timeout feedback.
- Add plugin IPC for Send now.
- Audit logs, argv, environment, and temp directories for clipboard leakage.

Exit criteria:

- Text copied in Omarchy can be sent to a selected Android phone.
- Text can be sent to iPhone when KDE Connect/iOS is in a supported state.
- Empty, binary, oversized, offline, and repeated-send cases behave as specified.

### Phase 5 — Receive verification and integration

- Verify phone-to-Omarchy text clipboard behavior.
- Confirm received content is visible through `wl-paste`.
- Confirm existing Omarchy clipboard history captures it exactly once.
- Document mobile OS gestures/foreground requirements.
- Only if the native path fails, write a separate fallback design proposal.

Exit criteria:

- At least one supported Android flow and one supported iPhone flow are
  documented with tested steps.
- No duplicate history entry or feedback loop is caused by plugin code.

### Phase 6 — Hardening and release

- Add pause state and privacy copy.
- Add redacted diagnostics.
- Run injection, timeout, malformed-output, and rapid-reconnect tests.
- Validate plugin with `omarchy plugin validate .`.
- Test add, enable, disable, update, and remove lifecycle.
- Add setup and troubleshooting documentation.
- Tag `v0.1.0` only after acceptance criteria pass.

### Phase 7 — Optional remote connectivity

- Test KDE Connect custom device addresses over Tailscale.
- Specify safe, atomic preservation of KDE Connect configuration.
- Detect but do not require Tailscale.
- Clearly label connection path as local or remote only if it can be determined
  reliably.
- Do not ship this phase as part of the v1 critical path.

## 17. Test plan

### 17.1 Static validation

- `omarchy plugin validate .` exits successfully.
- All QML files pass the available QML linter with Omarchy import paths.
- Adapter passes the selected shell/static-analysis tool.
- Manifest ID is not in the reserved `omarchy.*` namespace.
- Every entry point exists with exact case-sensitive paths.

### 17.2 Adapter tests

- Dependency missing.
- Unsupported KDE Connect version.
- Daemon unavailable and recovery.
- No devices discovered.
- Multiple devices with duplicate display names.
- Unicode and shell-metacharacter device names.
- Paired online, paired offline, and unpaired online states.
- Pair accepted, rejected, and timed out.
- Send success, offline failure, timeout, and process crash.
- Malformed, partial, empty, oversized, and translated CLI output.
- Child command exceeds output limit.
- Two refresh requests complete out of order.

### 17.3 Clipboard tests

- Empty clipboard.
- ASCII text.
- Unicode, emoji, combining characters, and right-to-left text.
- Multiline text with trailing newline.
- Exactly 64 KiB UTF-8.
- One byte over the limit.
- Image-only clipboard.
- Clipboard offering both text and HTML uses plain text only.
- Text beginning with `-` is not treated as an option.
- Text containing quotes, backticks, `$()`, newlines, NUL attempts, and shell
  metacharacters never enters a shell command or diagnostic.
- Received text appears once in Omarchy clipboard history.
- Send to one selected device does not reach another paired device through
  plugin behavior.

### 17.4 Physical-device matrix

| Platform | Same LAN | Desktop → phone | Phone → desktop | Background behavior | Required for v1 |
|---|---:|---:|---:|---:|---:|
| Current Android | Yes | Yes | Document tested flow | Document | Yes |
| Android 10+ reference device | Yes | Yes | Document restriction | Document | Preferred |
| Current iOS | Yes | Supported explicit flow | Supported explicit flow | Must state limitation | Yes |
| Omarchy over Ethernet + phone Wi-Fi | Yes | Yes | Yes | N/A | Yes |
| Guest Wi-Fi with client isolation | Expected failure | Clear error | Clear error | N/A | Yes |
| Tailscale across networks | No shared LAN | Experimental | Experimental | Document | No |

Record exact OS, KDE Connect app, desktop KDE Connect, Omarchy, and Quickshell
versions for every manual test run.

### 17.5 Lifecycle tests

- Enable plugin.
- Disable and re-enable plugin.
- Restart shell.
- Restart `kdeconnectd`.
- Suspend/resume laptop.
- Phone leaves and rejoins Wi-Fi.
- Network changes from Wi-Fi to Ethernet.
- Selected device is unpaired from the phone.
- Plugin update occurs while disabled.
- Plugin removal leaves KDE Connect pairing untouched unless explicitly
  documented otherwise.

## 18. v1 acceptance criteria

The release is complete only when all statements below are true:

1. The project validates as an Omarchy third-party plugin.
2. Missing KDE Connect produces a useful, non-destructive setup state.
3. The panel lists discovered devices with correct paired/reachable state.
4. A user can request pairing with a phone from the Omarchy experience.
5. Exactly one paired device can be selected as the target.
6. Manual Send now transfers UTF-8 text up to 64 KiB to that target on a
   healthy same-LAN connection.
7. Empty, non-text, oversized, offline, unpaired, and timeout paths have clear
   non-crashing behavior.
8. A tested phone-to-Omarchy flow updates the Wayland clipboard.
9. Received text is available through the existing Omarchy clipboard manager
   without a plugin-owned history store.
10. iPhone limitations are clearly documented and no silent background-sync
    claim is made.
11. Manual mode is the default and Pause visibly blocks outbound actions.
12. Clipboard content does not appear in logs, config, process arguments,
    environment variables, notifications, diagnostics, or plugin temp files.
13. Device names and IDs cannot cause shell injection.
14. Shell and KDE Connect restarts recover without re-pairing.
15. Setup, Android, iOS, privacy, and troubleshooting documentation exists.

### 18.1 Implementation verification status

As of 2026-09-08, the plugin, adapter, documentation, and automated fixture
suite are implemented. The project validates as an Omarchy plugin, loads in a
live Omarchy shell, and its IPC, pause/resume persistence, discovery-empty
state, dependency detection, and error paths have been exercised on the target
machine.

The physical-device items in criteria 3–9 and 14 remain release-validation
work because no Android phone or iPhone was discoverable during this run. They
must not be reported as physically verified until the matrix in section 17.4
has been executed. See [the test report](../../docs/test-report.md) for exact
versions, commands, and results.

## 19. Release and compatibility policy

- Initial release version: `0.1.0`.
- Omarchy baseline: 4.x plugin manifest schema version 1.
- KDE Connect tested desktop version: 26.08.0; older versions are not yet
  claimed as supported.
- Android/iOS compatibility statements must name tested OS and app versions.
- Unsupported KDE Connect versions should fail with `UNSUPPORTED_VERSION`, not
  best-effort parsing that may target the wrong device.
- Manifest and adapter changes follow semantic versioning once `1.0.0` is
  published.
- No plugin update may silently switch a user from manual to automatic mode.

## 20. Open questions

These must be answered during the Phase 0 spike:

1. Does the current Arch KDE Connect package set the Wayland clipboard
   correctly when run under Omarchy/Hyprland without Plasma services?
2. Which KDE Connect D-Bus properties and signals are stable enough for device
   state and pairing progress?
3. Does current `kdeconnect-cli --send-clipboard` target exactly one device
   when passed a stable device ID?
4. Can current KDE Connect iOS receive desktop clipboard text while foregrounded,
   and what exact action makes phone-to-desktop text available?
5. What Android behavior is available without making KDE Connect the default
   keyboard?
6. Does the desktop package expose a structured capability indicating that the
   remote device supports clipboard packets?
7. Can incoming pairing requests be accepted through a safe D-Bus method, or
   should v1 only guide outgoing pairing?
8. What import path/configuration is needed to run `qmllint` against Omarchy's
   custom `qs.Commons` and `qs.Ui` modules in CI?
9. Should the final public plugin ID remain `dimasmufid.clipboard-sync`?

## 21. Future work

Future specifications may cover:

- automatic outbound sync after physical-device privacy testing;
- custom Android Quick Settings integration;
- an iOS Shortcut/share extension or dedicated app;
- Tailscale custom-device setup;
- multiple simultaneous targets;
- image clipboard payloads with strict size and lifetime policies;
- device-specific allowlists and schedules;
- a temporary `private clipboard` mode;
- direct notification integration with the Omarchy shell;
- upstreaming useful generic UI or adapter behavior to Omarchy or KDE Connect.

## 22. References

- [Project README](../../README.md)
- [Project architecture](../../docs/architecture.md)
- [KDE Connect protocol reference](https://github.com/KDE/kdeconnect-meta/blob/work/protocol-schemas/protocol.md)
- [KDE Connect CLI source](https://github.com/KDE/kdeconnect-kde/blob/master/cli/kdeconnect-cli.cpp)
- [KDE Connect pairing and custom-device guidance](https://userbase.kde.org/KDEConnect/en)
- [Android 10 clipboard privacy restrictions](https://developer.android.com/about/versions/10/privacy/changes)
- [Apple UIPasteboard documentation](https://developer.apple.com/documentation/uikit/uipasteboard/)
- [Apple Handoff and Universal Clipboard security](https://support.apple.com/en-ie/guide/security/secf78dbe639/web)
