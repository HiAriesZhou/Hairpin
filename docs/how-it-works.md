# How Hairpin works

Hairpin finds the menu bar items macOS hides when they don't fit, keeps them behind a pin at the left end of the shown items, and opens them on request. The logic that decides what's hidden, in what order and where the pin goes lives in the `HairpinCore` module, which has unit tests (`swift test`). The `Hairpin` app target wraps it in AppKit.

## Reading the menu bar

- **Items, through Accessibility.** On a background queue, Hairpin calls `AXUIElementCreateApplication(pid)` for each running app and reads the children of its `AXExtrasMenuBar`: one `AXMenuBarItem` per menu bar item, with its title, description, position and size. Every request has a 0.25 s timeout, so a hung app only leaves out its own items.
- **Windows, through the window server.** `CGWindowListCopyWindowInfo` lists every status item window. Each menu bar has its own row of windows (a display's row sits at its top edge, or parked above it while that menu bar is hidden).
- **What's hidden.** On macOS 26 an overflowed item's window stays in its row but is ordered out, and that flag is what counts. On earlier systems an item drawn under the notch, or left of it under the frontmost app's menus, counts as hidden too. Items are judged on the notched display, or the primary one without a notch.
- **Matching windows to items.** Accessibility can report a stale position after the row is laid out again, and on another display. With Screen Recording granted, the active menu bar names each window after its app's bundle ID (or PID), so items are matched by name and then mapped to the notched display's row by place and width. Without names, Hairpin matches by position.
- **Across displays.** Accessibility reports items in whichever menu bar is active, and on macOS 26 the rows don't keep one order: the notched row moves the windows it hides to its left end, the others don't. So an item owns every window it has been reported on, in any row, and keeps it while it lives (macOS can hand an item's windows to the other display, so the ID, not the row, is what's remembered); an item reported elsewhere is judged by its owned window in the notched row. Hairpin's own windows are found by making its icon 2 points wider for a quarter second and seeing which windows grew; that's done only while they aren't known (at launch, after macOS makes new ones). With its windows left out, the other rows line up again for items not yet seen in the notched row. Zero-sized accessibility elements, such as Control Center modules that aren't shown, are dropped.

## Keeping up

Hairpin rescans when apps launch, quit or switch (again 0.4 s after a switch, once the new app's menus are in), when spaces change and when displays change. Twice a second it also reads the window list alone, which is cheap. When windows move or change whether they're drawn, it replays the last scan against the new list right away. When windows appear or go away, it starts a new Accessibility scan, at most every 2 s.

## Placing the pin

With nothing hidden there's no pin. While Hairpin's own icon is shown in the notched menu bar, wherever it is among the items, that icon holds the hidden items itself, so there's never a pin beside it. Otherwise the pin sits at the left end of the shown items, in the first free slot that covers neither the frontmost app's menus (which can run past the notch) nor any item: right of the notch, else left of it. With no room, it sits on the leftmost shown item on an opaque capsule and lists that item with the hidden ones. While the menu bar is hidden, so is the pin.

## Showing items

With Screen Recording (macOS 14 or later), Hairpin captures the menu bar strip once while an item is shown: one ScreenCaptureKit shot as is, one without the menu bar's windows. The difference between the two is the item's shape, kept as a template image so it takes the row's light or dark look. A hidden item isn't drawn, so it shows as it last looked; an item never seen (or any item, without Screen Recording) shows its app's own icon, or, for Apple's items and apps without an icon, the app's initial in a rounded square. Captures are keyed by the item's status window, tried once with a couple of retries, and kept only in memory. ScreenCaptureKit can turn on the recording indicator, which is why captures are rare.

The row orders items the way the menu bar adds them: Apple's on the right, the others by launch, the earliest rightmost.

## Opening an item

Clicking an item in the row performs `AXPress` on the real one, or `AXShowMenu` if it doesn't support `AXPress`. The app opens its own menu, at the real item's position.
