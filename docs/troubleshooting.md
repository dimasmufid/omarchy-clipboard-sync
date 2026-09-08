# Troubleshooting

## Check status

```bash
omarchy-shell dimasmufid.clipboard-sync status
omarchy-shell dimasmufid.clipboard-sync refresh
kdeconnect-cli --version
kdeconnect-cli --list-devices
```

The adapter provides structured diagnostics without clipboard content:

```bash
./scripts/clipboard-sync-adapter doctor
./scripts/clipboard-sync-adapter devices
```

## KDE Connect is required

Install it explicitly and retry:

```bash
omarchy pkg add kdeconnect
omarchy-shell dimasmufid.clipboard-sync refresh
```

The D-Bus service normally starts on demand.

## No phones found

- Keep KDE Connect open on the phone for initial discovery.
- Confirm the devices can reach each other on the local network.
- A computer on Ethernet and phone on Wi-Fi is valid when the router bridges
  them normally.
- Guest Wi-Fi and access-point client isolation often block discovery.
- VPN and firewall policy can block KDE Connect.
- KDE Connect commonly uses TCP and UDP ports 1714–1764. Review the active
  firewall before making any change; the plugin never changes it automatically.

For UFW, prefer rules restricted to the current LAN instead of exposing the
ports to every source. Replace the example subnet with the LAN reported by
`ip route`:

```bash
sudo ufw allow proto tcp from 192.168.100.0/24 to any port 1714:1764 \
  comment 'KDE Connect LAN'
sudo ufw allow proto udp from 192.168.100.0/24 to any port 1714:1764 \
  comment 'KDE Connect LAN'
sudo ufw reload
```

These rules may need to be replaced when the computer moves to a LAN with a
different subnet.

## Paired phone is offline

- Wake the phone and open KDE Connect.
- Refresh from the panel.
- Check phone battery/background restrictions.
- Confirm the phone did not switch to cellular data or another Wi-Fi network.

## Clipboard cannot be sent

Version 1 accepts non-empty UTF-8 plain text up to 64 KiB. Images, HTML-only
clipboard values, binary data, and larger text are rejected. Also confirm the
selected phone is paired, online, and that sharing is not paused.

## iPhone does not sync silently

This is expected. Open KDE Connect and use an explicit clipboard/share action.
iOS does not provide continuous background clipboard monitoring to ordinary
third-party applications.

## Shell logs

```bash
journalctl --user --since '-10 minutes' --no-pager | \
  rg -i 'clipboard-sync|kdeconnect|qml.*error'
```

Logs should never contain clipboard content. Do not paste unreviewed diagnostic
output into a public issue.

## Reload the development plugin

```bash
omarchy-shell shell rescanPlugins
omarchy-shell dimasmufid.clipboard-sync refresh
```

Files under the user plugin directory hot-reload. If a development symlink was
removed, rescan the plugin registry afterward.

## Tailscale

Remote Tailscale connectivity is not implemented in v1. KDE Connect broadcast
discovery generally does not cross a tailnet; a later version can manage KDE
Connect custom device addresses explicitly.
