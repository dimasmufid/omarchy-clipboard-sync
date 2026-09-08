# iPhone setup

## Pair the iPhone

1. Install the official KDE Connect application from the App Store.
2. Allow KDE Connect to access the local network when iOS asks.
3. Put the iPhone and Omarchy computer on the same reachable local network.
4. Keep KDE Connect open on the iPhone during initial discovery and pairing.
5. Open Clipboard Sync from the Omarchy bar and select **Refresh**.
6. Select the iPhone, choose **Pair**, and accept the matching request in KDE
   Connect on iPhone.

## Omarchy to iPhone

1. Open KDE Connect on iPhone when required by the current iOS/app version.
2. Copy plain text in Omarchy.
3. Choose **Send** in Clipboard Sync.
4. Paste through the normal iOS paste action.

## iPhone to Omarchy

Use the explicit clipboard or share action exposed by KDE Connect. Keep the app
foregrounded if iOS does not allow the operation while suspended. Received text
becomes the normal Wayland clipboard and should appear in Omarchy's clipboard
history.

## iOS limitation

iOS does not give ordinary third-party apps a general-purpose background hook
for every clipboard change. This plugin therefore cannot reproduce the silent
iPhone-to-Mac Universal Clipboard experience. Foreground use, a share action,
or another clear user gesture is expected.

If iOS displays a paste-access prompt, approve it only when you intended KDE
Connect to read the clipboard.
