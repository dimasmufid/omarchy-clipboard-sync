# Test Report

- Date: 2026-09-08
- Host: Omarchy 4.0.2-1, Quickshell 0.3.1-1
- Desktop dependencies: KDE Connect 26.08.0-1, wl-clipboard 2.3.0-1

## Automated verification

`./tests/run.sh` completed successfully:

- `omarchy plugin validate .` accepted the manifest and entry points.
- Python bytecode compilation succeeded for the adapter and its tests.
- All 24 adapter tests passed.
- The tests cover dependency detection, device parsing, duplicate and hostile
  names, pairing outcomes, selected-device sending, MIME and UTF-8 validation,
  empty and oversized clipboards, offline/unpaired distinctions, timeouts,
  daemon failures, and malformed command output.
- `qmllint` was not installed. QML was instead validated by loading the plugin
  in the live Omarchy shell and checking the shell journal for plugin errors.

The tests use isolated fake `kdeconnect-cli` and `wl-paste` programs. They do
not put real clipboard content in process arguments, environment variables, or
logs.

## Live Omarchy verification

The checkout was linked at
`~/.config/omarchy/plugins/dimasmufid.clipboard-sync`, rescanned, and enabled in
the right bar section. The following live checks succeeded:

- The bar widget and panel rendered using Omarchy components.
- `open`, `close`, `refresh`, `send`, `pause`, `resume`, and `status` IPC calls
  were accepted without a shell crash.
- Pause and resume persisted through the Omarchy shell entry settings.
- Before KDE Connect was installed, the panel reported the missing dependency.
- After installation, the adapter reported KDE Connect 26.08.0 and the panel
  transitioned to the no-devices state.
- Direct `doctor` and `devices` adapter calls returned valid JSON envelopes.
- The session D-Bus fallback successfully reached the on-demand KDE Connect
  daemon from the adapter.
- No plugin-specific QML errors appeared in the shell journal during these
  checks.

## Pending physical-device validation

No phone was discoverable or paired during this run. Consequently, the
following behaviors have not yet been verified on real hardware:

- Android and iPhone pairing approval.
- Desktop-to-phone clipboard delivery and latency.
- Phone-to-desktop delivery into the Wayland clipboard and Omarchy history.
- Foreground/background behavior of the current mobile apps.
- Ethernet-to-Wi-Fi operation, client-isolated guest Wi-Fi diagnostics, and
  recovery after phone/network/suspend transitions.

Run the relevant setup guide and repeat the physical-device matrix in the
[specification](../ai/specs/clipboard-sync-v1.md) before calling version 1
release-validated.
