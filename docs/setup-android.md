# Android setup

## Pair the phone

1. Install the official KDE Connect application on Android.
2. Put Android and the Omarchy computer on the same reachable local network.
3. Open KDE Connect on Android and leave its device screen visible during
   initial pairing.
4. Open Clipboard Sync from the Omarchy bar and select **Refresh**.
5. Select the Android device and choose **Pair**.
6. Confirm the matching pairing request on Android.
7. Select the paired device if it is not selected automatically.

## Omarchy to Android

1. Copy plain text in Omarchy.
2. Open Clipboard Sync and choose **Send**.
3. Paste on Android using the destination application's normal paste action.

The panel reports **Sent to KDE Connect** because the KDE Connect CLI confirms
that it accepted the operation, not that another application has pasted it.

## Android to Omarchy

Android 10 and newer restrict background clipboard reads. Depending on the
Android and KDE Connect versions, use KDE Connect's explicit **Send clipboard**
action, foreground app, notification action, or share action. After receipt,
paste normally in Omarchy or open Omarchy's clipboard history.

Do not grant accessibility, root, or default-keyboard privileges merely to
circumvent clipboard restrictions. Version 1 does not require them.

## If the phone disappears

- Disable battery optimization for KDE Connect only if Android is suspending
  its network connection and you accept the battery tradeoff.
- Confirm both devices remain on the same reachable network.
- Open KDE Connect on Android and select **Refresh** in the Omarchy panel.
- Check Android's local-network, nearby-device, and notification permissions as
  offered by that OS version.

See [troubleshooting](troubleshooting.md) for network diagnostics.
