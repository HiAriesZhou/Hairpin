# NotchBar acceptance checklist

Run on a notched MacBook (14"/16" MacBook Pro 2021+, or MacBook Air M2+) on macOS 13 or later.
Tick each box; record the macOS version, Mac model and NotchBar version at the bottom.

## Setup

- [ ] Install enough menu bar apps that some icons disappear behind the notch. Good candidates: several third-party utilities plus Control Center items (Wi‑Fi, Bluetooth, Sound and Battery set to "Show in Menu Bar"). Open a frontmost app with many menus (e.g. Xcode, Finder with a window) so the left half of the menu bar is full.
- [ ] Note which icons you can no longer see.

## Install and first launch

- [ ] Download `NotchBar.zip` from the release, unzip, move `NotchBar.app` to /Applications.
- [ ] Double-clicking is blocked by Gatekeeper; **right-click → Open → Open** launches it. (Alternatively `xattr -dr com.apple.quarantine /Applications/NotchBar.app`, then double-click.)
- [ ] No Dock icon and no app menu appear (agent app); one NotchBar icon appears in the menu bar.
- [ ] Finder › Get Info shows version 0.1.0 (or the tag you're testing).

## Accessibility permission

Start without permission (System Settings › Privacy & Security › Accessibility: NotchBar absent or off; `tccutil reset Accessibility com.hiarieszhou.notchbar` resets it).

- [ ] On launch, an alert explains why Accessibility is needed, with "Open System Settings" and "Later".
- [ ] "Open System Settings" opens the Accessibility pane directly.
- [ ] NotchBar is listed there (or can be added with "+").
- [ ] Before granting, clicking the NotchBar icon shows "Grant Accessibility…", then a separator, "Launch at Login" and "Quit NotchBar". Nothing else.
- [ ] "Grant Accessibility…" shows the same alert again.
- [ ] After turning NotchBar on (no relaunch), clicking the NotchBar icon lists menu bar items.

## Listing

- [ ] The menu opens within about half a second.
- [ ] A "Hidden by the notch" section lists the icons you noted as missing, before a "Visible" section.
- [ ] Icons you can see appear under "Visible", in left-to-right menu bar order.
- [ ] Each entry shows the owning app's icon, and the app name plus title/description where available (e.g. "Control Center — Wi‑Fi").
- [ ] NotchBar's own icon is not listed.
- [ ] Switching to an app with few menus (e.g. Calculator) and reopening the list: icons that became visible move to "Visible".
- [ ] Quitting a menu bar app and reopening the list: its entries are gone. Launching it: they appear.
- [ ] A hung or slow app doesn't freeze the list (optional: `kill -STOP <pid>` a menu bar app, open the list, then `kill -CONT <pid>`).

## Opening items

- [ ] Selecting a **visible** entry opens that icon's menu, the same as clicking it directly.
- [ ] Selecting a **hidden** entry opens its menu or window. Note any app whose menu opens under the notch or partly offscreen; that's a known limitation, not a failure.
- [ ] Selecting a Control Center item (e.g. Wi‑Fi or Sound) opens its panel.
- [ ] The NotchBar menu closes first and never stays stuck open; NotchBar stays responsive afterwards.
- [ ] Note any app that doesn't respond at all (known limitation; record it).

## Launch at Login

- [ ] "Launch at Login" starts unchecked. Selecting it checks it (or opens Login Items settings if macOS asks for approval).
- [ ] NotchBar appears in System Settings › General › Login Items.
- [ ] Log out and back in: NotchBar starts automatically.
- [ ] Unchecking it removes it from Login Items; after the next login NotchBar doesn't start.

## Multiple displays (optional)

- [ ] With an external display attached, the list still opens and icons on the external menu bar appear under "Visible".
- [ ] With the lid closed (external display only), nothing is marked hidden by the notch.

## Quit

- [ ] "Quit NotchBar" (or ⌘Q with the menu open) removes the icon and terminates the process.

---

| Field | Value |
|---|---|
| macOS version | |
| Mac model | |
| NotchBar version | |
| Tester / date | |
| Apps that didn't open | |
