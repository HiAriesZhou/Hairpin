# Hairpin acceptance checklist

Run on a notched MacBook (14"/16" MacBook Pro 2021+, or MacBook Air M2+) on macOS 13 or later. The release is arm64-only.
Tick each box; record the macOS version, Mac model and Hairpin version at the bottom.

## Setup

- [ ] Install enough menu bar apps that some icons disappear behind the notch. Good candidates: several third-party utilities plus Control Center items (Wi‑Fi, Bluetooth, Sound and Battery set to "Show in Menu Bar"). Open a frontmost app with many menus (e.g. Xcode, Finder with a window) so the left half of the menu bar is full.
- [ ] Note which icons you can no longer see.

## Install and first launch

- [ ] Download `Hairpin.zip` from the release, unzip, move `Hairpin.app` to /Applications.
- [ ] Double-clicking is blocked by Gatekeeper; **right-click → Open → Open** launches it. (Alternatively `xattr -dr com.apple.quarantine /Applications/Hairpin.app`, then double-click.)
- [ ] No Dock icon and no app menu appear (agent app); one Hairpin icon appears in the menu bar.
- [ ] On a first launch (fresh user defaults: `defaults delete com.hiarieszhou.hairpin`), the Hairpin icon sits at the right end of the third-party icons, next to the system ones (Control Center, clock).
- [ ] Finder › Get Info shows version 0.1.1 (or the tag you're testing).
- [ ] `Hairpin.app/Contents/Resources/LICENSE` exists.

## Accessibility permission

Start without permission (System Settings › Privacy & Security › Accessibility: Hairpin absent or off; `tccutil reset Accessibility com.hiarieszhou.hairpin` resets it).

Note: the bundle ID changed from `com.hiarieszhou.notchbar` (NotchBar builds) to `com.hiarieszhou.hairpin`. Grants given to the old NotchBar build don't apply; Accessibility (and Login Items) must be granted again for Hairpin.app.

- [ ] Upgrading from a NotchBar build that already had Accessibility: Hairpin starts without permission and shows the alert; turning Hairpin on in Accessibility makes it work.

- [ ] On launch, an alert explains why Accessibility is needed, with "Open System Settings" and "Later".
- [ ] "Open System Settings" opens the Accessibility pane directly.
- [ ] Hairpin is listed there (or can be added with "+").
- [ ] Before granting, clicking the Hairpin icon shows "Grant Accessibility…", then a separator, "Launch at Login" and "Quit Hairpin". Nothing else.
- [ ] "Grant Accessibility…" shows the same alert again.
- [ ] After turning Hairpin on (no relaunch), clicking the Hairpin icon lists menu bar items.

## Listing

- [ ] The menu opens within about half a second. Right after granting Accessibility it may show "Reading menu bar items…" briefly, then fill in without closing.
- [ ] A "Hidden by the notch" section lists the icons you noted as missing, before a "Visible" section.
- [ ] Icons you can see appear under "Visible", in left-to-right menu bar order.
- [ ] Items that report no position, if any, are listed last under "Position unknown", not under "Visible".
- [ ] Each entry shows the owning app's icon, and the app name plus title/description where available (e.g. "Control Center — Wi‑Fi").
- [ ] Hairpin's own icon is not listed.
- [ ] Switching to an app with few menus (e.g. Calculator) and reopening the list: icons that became visible move to "Visible". Also record whether macOS draws any status icons left of the notch at all on this Mac; if it never does, icons listed as "Visible" there would be a classification bug.
- [ ] Quitting a menu bar app and reopening the list: its entries are gone. Launching it: they appear.
- [ ] A hung or slow app doesn't freeze the list (optional: `kill -STOP <pid>` a menu bar app, open the list, then `kill -CONT <pid>`). The menu still opens at once; the stopped app's icons may be missing.

## Opening items

- [ ] Selecting a **visible** entry opens that icon's menu, the same as clicking it directly.
- [ ] Selecting a **hidden** entry opens its menu or window. Note any app whose menu opens under the notch or partly offscreen; that's a known limitation, not a failure.
- [ ] Selecting a Control Center item (e.g. Wi‑Fi or Sound) opens its panel.
- [ ] The Hairpin menu closes first and never stays stuck open; Hairpin stays responsive afterwards.
- [ ] Note any app that doesn't respond at all (known limitation; record it).

## Launch at Login

- [ ] "Launch at Login" starts unchecked. Selecting it checks it, or opens Login Items settings if macOS asks for approval.
- [ ] While approval is pending the item shows a dash (mixed state); selecting it again opens Login Items settings, with no error alert.
- [ ] Hairpin appears in System Settings › General › Login Items.
- [ ] Log out and back in: Hairpin starts automatically.
- [ ] Unchecking it removes it from Login Items; after the next login Hairpin doesn't start.

## Multiple displays (optional)

- [ ] With an external display attached, the list still opens and icons on the external menu bar appear under "Visible".
- [ ] With the lid closed (external display only), nothing is marked hidden by the notch.

## Hairpin's own icon

- [ ] With Hairpin running, opening Hairpin.app again from Finder or Spotlight pops the list up at the pointer, and entries work from there.

## Quit

- [ ] "Quit Hairpin" (or ⌘Q with the menu open) removes the icon and terminates the process.

---

| Field | Value |
|---|---|
| macOS version | |
| Mac model | |
| Hairpin version | |
| Tester / date | |
| Apps that didn't open | |
