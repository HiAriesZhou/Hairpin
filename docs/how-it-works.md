# How Hairpin works

Hairpin finds the menu bar items macOS hides when they don't fit, keeps them behind a pin at the left end of the shown items, and opens them on request. The logic that decides what's hidden, in what order and where the pin goes lives in the `HairpinCore` module, which has unit tests (`swift test`). The `Hairpin` app target wraps it in AppKit.

## Reading the menu bar

- **Items, through Accessibility.** On a background queue, Hairpin calls `AXUIElementCreateApplication(pid)` for each running app and reads the children of its `AXExtrasMenuBar`: one `AXMenuBarItem` per menu bar item, with its title, description, position and size. Every request has a 0.25 s timeout, so a hung app only leaves out its own items.
- **Windows, through the window server.** `CGWindowListCopyWindowInfo` lists every status item window. Each menu bar has its own row of windows (a display's row sits at its top edge, or parked above it while that menu bar is hidden).
- **What's hidden.** On macOS 26 an overflowed item's window stays in its row but is ordered out, and that flag is what counts. On earlier systems an item drawn under the notch, or left of it under the frontmost app's menus, counts as hidden too. Items are judged on the notched display, or the primary one without a notch.
- **Matching windows to items.** Accessibility can report a stale position after the row is laid out again, and on another display. With Screen Recording granted, the active menu bar names each window after its app's bundle ID (or PID), so items are matched by name and then mapped to the notched display's row by place and width. Without names, Hairpin matches by position. Zero-sized accessibility elements, such as Control Center modules that aren't shown, are dropped.

## Keeping up

Hairpin rescans when apps launch, quit or switch (again 0.4 s after a switch, once the new app's menus are in), when spaces change and when displays change. Twice a second it also reads the window list alone, which is cheap. When windows move or change whether they're drawn, it replays the last scan against the new list right away. When windows appear or go away, it starts a new Accessibility scan, at most every 2 s.

## Placing the pin

The pin sits at the left end of the shown items. It goes in the first free slot that covers neither the frontmost app's menus (which can run past the notch) nor any item: right of the notch, else left of it. With no room, it sits on the leftmost shown item on an opaque capsule and lists that item with the hidden ones. When Hairpin's own icon is the leftmost item, that icon holds the hidden items itself. While the menu bar is hidden, so is the pin.

## Showing items

With Screen Recording (macOS 14 or later), Hairpin captures the menu bar strip once while an item is shown: one ScreenCaptureKit shot as is, one without the menu bar's windows. The difference between the two is the item's shape, kept as a template image so it takes the row's light or dark look. A hidden item isn't drawn, so it shows as it last looked; an item never seen (or any item, without Screen Recording) shows its app's own icon, or, for Apple's items and apps without an icon, the app's initial in a rounded square. Captures are keyed by the item's status window, tried once with a couple of retries, and kept only in memory. ScreenCaptureKit can turn on the recording indicator, which is why captures are rare.

The row orders items the way the menu bar adds them: Apple's on the right, the others by launch, the earliest rightmost.

## Opening an item

Clicking an item in the row performs `AXPress` on the real one, or `AXShowMenu` if it doesn't support `AXPress`. The app opens its own menu, at the real item's position.
