# Hairpin acceptance checklist

Run on a notched MacBook (14"/16" MacBook Pro 2021+, or MacBook Air M2+) on macOS 13 or later; real icons need macOS 14, the Liquid Glass row macOS 26. The release is arm64-only.
Tick each box; record the macOS version, Mac model and Hairpin version at the bottom.

## Setup

- [ ] Install enough menu bar apps that some icons disappear behind the notch. Good candidates: several third-party utilities plus Control Center items (Wi‑Fi, Bluetooth, Sound and Battery set to "Show in Menu Bar").
- [ ] Note which icons you can no longer see.
- [ ] Find a frontmost app whose menus run past the notch (e.g. a browser with a localized UI, or Xcode) and one with short menus (e.g. Calculator).

## Install and first launch

- [ ] Download `Hairpin.dmg` from the release, open it: it shows `Hairpin.app` beside an Applications link; dragging the app onto the link installs it. (Or download `Hairpin.zip`, unzip, move `Hairpin.app` to /Applications.)
- [ ] Double-clicking opens it with no Gatekeeper warning; `spctl --assess --type execute --verbose=2 /Applications/Hairpin.app` says `accepted` and `source=Notarized Developer ID`.
- [ ] No Dock icon and no app menu appear (agent app); one Hairpin icon (a bow on a bobby pin) appears in the menu bar.
- [ ] On a first launch (fresh user defaults: `defaults delete com.hiarieszhou.hairpin`), the Hairpin icon joins the third-party icons at their left end, never right of Apple's (Control Center, clock, Wi‑Fi, battery).
- [ ] Finder › Get Info shows version 0.2.0 (or the tag you're testing).
- [ ] `Hairpin.app/Contents/Resources/LICENSE` exists.
- [ ] Finder, Launchpad and the Applications folder show the app icon (a pink bow on a bobby pin on a cream tile), not a generic app icon or a gray tile.

## Accessibility permission

Start without permission (System Settings › Privacy & Security › Accessibility: Hairpin absent or off; `tccutil reset Accessibility com.hiarieszhou.hairpin` resets it).

Note: the bundle ID changed from `com.hiarieszhou.notchbar` (NotchBar builds) to `com.hiarieszhou.hairpin`. Grants given to the old NotchBar build don't apply; Accessibility (and Login Items) must be granted again for Hairpin.app.

- [ ] Upgrading from a NotchBar build that already had Accessibility: Hairpin starts without permission and shows the alert; turning Hairpin on in Accessibility makes it work.
- [ ] On launch, an alert explains why Accessibility is needed, with "Open System Settings" and "Later".
- [ ] "Open System Settings" opens the Accessibility pane directly.
- [ ] Hairpin is listed there (or can be added with "+").
- [ ] Before granting, clicking the Hairpin icon shows "Grant Accessibility…", then a separator, "Open on Hover", "Launch at Login" and "Quit Hairpin". Nothing else.
- [ ] "Grant Accessibility…" shows the same alert again.
- [ ] After turning Hairpin on (no relaunch), the hairpin appears by the hidden icons within a few seconds (switching apps once triggers a rescan).

## Screen Recording (macOS 14 and later)

Start without it (`tccutil reset ScreenCapture com.hiarieszhou.hairpin`).

- [ ] Without it, the row shows each app's own icon in color; Apple's items (Control Center) and apps without an icon show the initial in a rounded square, crisp and monochrome. Nothing else is missing.
- [ ] The first time the row opens with icons hidden, macOS asks for Screen Recording. "Show Real Icons…" in the menu asks too (or opens the Screen Recording pane once macOS won't ask again).
- [ ] After granting it (relaunch if macOS asks), icons that were shown at the time show in the row as they look in the menu bar: monochrome, crisp, in the row's light or dark look. None is a noisy block or a blank.
- [ ] The recording indicator shows at most briefly, when new icons appear; not on every opening of the row.

## The hairpin

- [ ] With icons hidden, the hairpin appears at the left end of the shown icons, right of the notch, covering no icon and no app menu.
- [ ] With nothing hidden, the hairpin isn't there.
- [ ] Switching to the app with long menus: the hairpin moves so it covers none of them (left of the notch, or onto the leftmost shown icon on a capsule that hides it, and that icon then shows up in the row too). Switching back: it returns right of the notch.
- [ ] A running app adding a menu bar item (e.g. a timer starting, or Codex using the computer) moves the hairpin within about a second, without switching apps; it never ends up over a shown icon.
- [ ] With "Automatically hide and show the menu bar" on, the hairpin appears with the menu bar and goes with it, and opening Hairpin.app again still reaches the hidden icons or the menu.
- [ ] While Hairpin's own icon is shown, wherever it is, that icon is the hairpin: no separate pin appears, a click opens the row, a right-click or Control-click opens the menu.
- [ ] Relaunch a menu bar app so its icon lands left of Hairpin's, once with long app menus and once with short ones: no pin appears or covers it. With icons hidden, Hairpin's own icon holds them; with none hidden, no pin shows at all.
- [ ] In a full-screen app, the hairpin isn't shown.

## The row

- [ ] Resting the pointer on the hairpin for about half a second opens the row below it; moving away closes it.
- [ ] Clicking the hairpin opens the row; it stays when the pointer leaves, and closes on a click elsewhere, a second click on the hairpin, or Escape.
- [ ] Clicking the hairpin while a hover has the row open keeps it open (it doesn't close).
- [ ] Switching the system between light and dark recolors the hairpin at once.
- [ ] Opening and closing it several times in a row, by hover and by click, works every time.
- [ ] With "Open on Hover" off, resting the pointer does nothing and a click still opens the row. The setting survives a relaunch.
- [ ] The row lists exactly the icons you noted as missing. Hairpin's own icon is not listed, and no blank or duplicated entries appear.
- [ ] Apple's icons are rightmost; the others are ordered by launch, the earliest launched rightmost.
- [ ] Each icon lights up under the pointer, and its tooltip names the app (and the item, where it has a title, e.g. "Control Center — Wi‑Fi").
- [ ] On macOS 26 the row is Liquid Glass: no flash from dark to light when it opens, no dark outline. Earlier systems show a blur.
- [ ] Quitting a menu bar app removes its icon from the row; launching one that overflows adds it.
- [ ] A hung or slow app doesn't freeze Hairpin (optional: `kill -STOP <pid>` a menu bar app, open the row, then `kill -CONT <pid>`). The row still opens at once; the stopped app's icons may be missing.

## Opening items

- [ ] Clicking an icon in the row opens its menu or window, and the row stays open until you click elsewhere. Note any app whose menu opens under the notch or partly offscreen; that's a known limitation, not a failure.
- [ ] Clicking a Control Center item (e.g. Wi‑Fi or Sound), if one is hidden, opens its panel.
- [ ] Hairpin stays responsive afterwards.
- [ ] Note any app that doesn't respond at all (known limitation; record it).

## Hairpin's menu

- [ ] Clicking Hairpin's icon (right-clicking while it's the hairpin) shows the menu right under it, with the number of hidden icons first.
- [ ] Opening the menu closes the row.

## Launch at Login

- [ ] "Launch at Login" starts unchecked. Selecting it checks it, or opens Login Items settings if macOS asks for approval.
- [ ] While approval is pending the item shows a dash (mixed state); selecting it again opens Login Items settings, with no error alert.
- [ ] Hairpin appears in System Settings › General › Login Items.
- [ ] Log out and back in: Hairpin starts automatically.
- [ ] Unchecking it removes it from Login Items; after the next login Hairpin doesn't start.

## Multiple displays (optional)

- [ ] With an external display attached and active, icons hidden on the built-in display still appear in the row, each with its own look (no app showing another app's icon).
- [ ] With an external display attached, clicking in either display's menu bar or desktop, and opening an item from the row then clicking elsewhere, never shows a second hairpin beside Hairpin's own icon; while Hairpin's icon is the leftmost shown one on the built-in display, it alone holds the hidden items and its row opens right under it.
- [ ] With the lid closed (external display only), icons that overflow that menu bar are held by the hairpin there; nothing is marked hidden otherwise.

## Finding Hairpin

- [ ] With Hairpin running, opening Hairpin.app again from Finder or Spotlight opens the row under the hairpin, or at the pointer while the menu bar is hidden (with nothing hidden, the menu at the pointer).

## Quit

- [ ] "Quit Hairpin" (or ⌘Q with the menu open) removes the icon and the hairpin, and terminates the process.

---

| Field | Value |
|---|---|
| macOS version | |
| Mac model | |
| Hairpin version | |
| Tester / date | |
| Apps that didn't open | |
