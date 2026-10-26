# Hairpin

[![CI](https://github.com/HiAriesZhou/Hairpin/actions/workflows/ci.yml/badge.svg)](https://github.com/HiAriesZhou/Hairpin/actions/workflows/ci.yml)

A tiny macOS menu bar app that lets you reach the menu bar icons hidden behind the MacBook notch.
一个极简的 macOS 菜单栏小工具：让你点得到被 MacBook 刘海挡住的菜单栏图标。

> **Renamed:** this project and its GitHub repository were renamed from NotchBar to Hairpin. If you cloned the old repo, update the remote: `git remote set-url origin https://github.com/HiAriesZhou/Hairpin.git`
>
> **已改名**：本项目及其 GitHub 仓库已从 NotchBar 改名为 Hairpin。旧的克隆请更新远程地址：`git remote set-url origin https://github.com/HiAriesZhou/Hairpin.git`

[中文](#中文) · [English](#english)

---

## 中文

### 解决什么问题

在带刘海的 MacBook 上，菜单栏右侧空间有限。图标一多，macOS 会把放不下的图标排到刘海后面或刘海左侧，那里会被前台应用的菜单盖住。这些图标没有任何提示，也点不到。

Hairpin 只做一件事：在菜单栏放一个图标，点开后列出所有其他应用的菜单栏图标，被刘海挡住的排在最前面。点一下列表里的某一项，就会打开那个图标本来的菜单。

### 安装

1. 从 [Releases](https://github.com/HiAriesZhou/Hairpin/releases) 下载 `Hairpin.zip`，解压后把 `Hairpin.app` 拖进「应用程序」。
2. 这个应用是 ad-hoc 签名，没有经过 Apple 公证，第一次打开会被 Gatekeeper 拦下。两种办法任选一种：
   - 在 Finder 里**右键（或按住 Control 点按）Hairpin.app → 打开**，在弹出的对话框里再点「打开」；
   - 或者在终端执行：
     ```sh
     xattr -dr com.apple.quarantine /Applications/Hairpin.app
     ```
3. 系统要求：macOS 13 Ventura 或更高版本，Apple 芯片（arm64）。发布的是 arm64 版本，不是通用二进制；带刘海的 Mac 都是 Apple 芯片。

### 权限

- **辅助功能（必需）**：Hairpin 用辅助功能 API 读取其他应用的菜单栏图标，并替你「点击」它们。第一次运行会弹窗说明，点「Open System Settings」后，在「系统设置 › 隐私与安全性 › 辅助功能」里打开 Hairpin。如果列表里没有它，点「+」手动添加 `Hairpin.app`。授权之前，菜单里只有「Grant Accessibility…」、「Launch at Login」和「Quit Hairpin」三项。
- **从旧版 NotchBar 升级**：Bundle ID 已从 `com.hiarieszhou.notchbar` 改为 `com.hiarieszhou.hairpin`，macOS 把它当作一个新应用，旧版的辅助功能授权和登录项都不会沿用。请在「辅助功能」里重新为 Hairpin.app 打开授权，需要的话重新勾选「Launch at Login」；旧的 NotchBar 条目可以用「−」删掉。
- **屏幕录制**：不需要。Hairpin 显示的是应用图标，不截取菜单栏画面。

Hairpin 不联网，不读取窗口内容，也不记录按键。

### 使用

- 点击菜单栏里的 Hairpin 图标，弹出列表：
  - **Hidden by the notch**：在刘海后面、在屏幕外，或在刘海左侧被前台应用菜单盖住的图标；
  - **Visible**：当前能看到的图标；
  - **Position unknown**：读不到位置的图标。
- 点击某一项，会打开对应图标的菜单。
- 列表在后台读取。菜单打开时立即显示最近一次的结果，如果有变化会就地更新。
- **Launch at Login**：登录时自动启动（使用 `SMAppService`）。如果 macOS 要求你批准，这一项会显示为「–」，点它会打开「系统设置 › 通用 › 登录项」。
- **Quit Hairpin**：退出。
- 如果 Hairpin 自己的图标也被刘海挡住了：在 Hairpin 运行时，从访达、聚焦搜索或启动台再打开一次 Hairpin.app，列表会在鼠标指针处弹出。

### 工作原理

1. 在后台线程遍历正在运行的应用，对每个应用调用 `AXUIElementCreateApplication(pid)`，读取 `AXExtrasMenuBar` 属性，它的子元素（`AXMenuBarItem`）就是这个应用的菜单栏图标。同时读取标题、描述、位置和大小。启动时、应用启动/退出/切换时、屏幕变化时，以及每次打开菜单时都会重新读取。
2. 用 `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 算出刘海的位置，再读取前台应用的 `AXMenuBar`，得到它的菜单延伸到哪里。图标与刘海重叠，或在刘海左侧且被前台应用的菜单盖住，就判定为被刘海挡住；读不到前台应用的菜单时，刘海左侧的图标一律算被挡住。大部分不在任何屏幕上的，判定为在屏幕外。
3. 你选中某一项后，Hairpin 对那个真实的图标执行 `AXPress`，不支持时改用 `AXShowMenu`，于是应用自己的菜单就打开了。

判断与排序逻辑在独立的 `HairpinCore` 模块里，有单元测试（`swift test`）。

### 已知限制

- **不会真正移动图标。** Hairpin 不改变图标在菜单栏上的位置，只是替你点击它。
- **菜单可能出现在刘海下面。** 菜单是应用自己弹出的，位置跟着真实图标走。如果图标在刘海后面，有些应用的菜单会贴着刘海弹出，部分内容可能被挡住或被挤到一边。
- 有些应用的图标不响应 `AXPress` / `AXShowMenu`，或者点了之后打开的是自定义窗口而不是菜单，这取决于应用自己的实现。
- 有些图标没有标题或描述，列表里只显示应用名；同一个应用有多个图标时，可能很难区分。
- 未响应的应用会被跳过：每个辅助功能请求的超时是 0.25 秒，而且读取在后台进行，所以卡住的应用只会让它自己的图标不出现在列表里，不会卡住菜单。
- **Hairpin 自己的图标也可能被刘海挡住。** 第一次启动时，它会向 macOS 请求最靠右的位置（紧挨着系统图标），图标放不下时那里最后才会被挤到刘海后面。如果你挪动过它，按住 ⌘ 把它拖回右边。万一还是被挡住，就再打开一次 Hairpin.app，列表会在鼠标指针处弹出。没有全局快捷键。
- 刘海判断依赖系统提供的屏幕信息。外接显示器（没有刘海）上不会把图标标成「被挡住」。
- 应用采用 ad-hoc 签名，**每次更新到新版本后，可能需要在「辅助功能」里重新授权**（先删掉旧条目再添加）。
- 只支持 macOS 13 及以上、Apple 芯片的 Mac。

### 从源码构建

```sh
swift test               # 运行单元测试
scripts/bundle.sh        # 生成 Hairpin.app 和 Hairpin.zip
```

需要安装 Xcode 或 Command Line Tools 的 macOS。

---

## English

### The problem

On a notched MacBook the right side of the menu bar is short. When there are too many menu bar icons, macOS lays the extra ones out behind the notch or to its left, where the frontmost app's menus cover them. They vanish without a trace, and you can't click them.

Hairpin does one thing. It puts an icon in the menu bar; click it to list every other app's menu bar icon, with the ones hidden by the notch at the top. Pick an entry and that icon's own menu opens.

### Install

1. Download `Hairpin.zip` from [Releases](https://github.com/HiAriesZhou/Hairpin/releases), unzip it and drag `Hairpin.app` into Applications.
2. The app is ad-hoc signed and not notarized, so Gatekeeper blocks the first launch. Either:
   - **Right-click (or Control-click) Hairpin.app in Finder → Open**, then click Open in the dialog; or
   - run:
     ```sh
     xattr -dr com.apple.quarantine /Applications/Hairpin.app
     ```
3. Requires macOS 13 Ventura or later on Apple silicon (arm64). The release is an arm64 build, not a universal one; every notched Mac is Apple silicon.

### Permissions

- **Accessibility (required).** Hairpin reads other apps' menu bar icons and "clicks" them through the Accessibility API. On first launch an alert explains this; click "Open System Settings" and turn on Hairpin under System Settings › Privacy & Security › Accessibility. If it isn't listed, click "+" and add `Hairpin.app`. Until you grant it, the menu shows only "Grant Accessibility…", "Launch at Login" and "Quit Hairpin".
- **Upgrading from NotchBar.** The bundle ID changed from `com.hiarieszhou.notchbar` to `com.hiarieszhou.hairpin`, so macOS treats Hairpin as a new app and the old Accessibility and Login Items grants don't carry over. Turn Accessibility on again for Hairpin.app, and re-enable "Launch at Login" if you used it. You can remove the old NotchBar entry with "−".
- **Screen Recording: not needed.** Hairpin shows app icons and doesn't capture the menu bar.

Hairpin makes no network connections, doesn't read window contents and doesn't log keystrokes.

### Usage

- Click the Hairpin icon in the menu bar:
  - **Hidden by the notch**: icons behind the notch, offscreen, or left of the notch where the frontmost app's menus cover them;
  - **Visible**: icons you can already see;
  - **Position unknown**: icons that report no position.
- Click an entry to open that icon's menu.
- The list is read in the background. The menu opens straight away with the latest result and updates in place if anything changed.
- **Launch at Login** starts Hairpin when you log in (via `SMAppService`). If macOS asks for approval, the item shows a dash and opens System Settings › General › Login Items.
- **Quit Hairpin** quits.
- If Hairpin's own icon is hidden too, open Hairpin.app again while it's running (Finder, Spotlight or Launchpad). The list pops up at the pointer.

### How it works

1. On a background thread, for each running app, Hairpin calls `AXUIElementCreateApplication(pid)` and reads the `AXExtrasMenuBar` attribute. Its children (`AXMenuBarItem`) are the app's menu bar icons. It also reads each icon's title, description, position and size. It rescans at launch, when apps launch, quit or switch, when screens change, and every time you open the menu.
2. It works out where the notch is from `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, and how far the frontmost app's menus reach from that app's `AXMenuBar`. An icon that overlaps the notch counts as hidden by the notch. So does one left of the notch that the app's menus cover; if those menus can't be read, everything left of the notch counts as hidden. An icon that's mostly off every screen counts as offscreen.
3. When you pick an entry, Hairpin performs `AXPress` on the real icon, or `AXShowMenu` if the icon doesn't support `AXPress`, and the app opens its own menu.

The classification and sorting logic lives in a separate `HairpinCore` module with unit tests (`swift test`).

### Known limitations

- **It doesn't physically move icons.** Hairpin leaves each icon where it is in the menu bar and just clicks it for you.
- **Menus can open under the notch.** The app opens its own menu at the real icon's position. When that icon is behind the notch, some apps' menus open against the notch and may be partly hidden or pushed aside.
- Some icons don't respond to `AXPress` / `AXShowMenu`, or open a custom window instead of a menu. That depends on how each app is built.
- Some icons have no title or description, so the list shows only the app name, and several icons from the same app can be hard to tell apart.
- Unresponsive apps are skipped. Every Accessibility request has a 0.25 s timeout and the scan runs in the background, so a hung app only leaves its own icons out of the list; it can't freeze the menu.
- **Hairpin's own icon can end up behind the notch too.** On first launch it asks macOS for the rightmost slot, next to the system icons, which is the last one to overflow. If you've moved it, ⌘-drag it back to the right. If it's hidden anyway, open Hairpin.app again to show the list at the pointer. There's no global hotkey.
- Notch detection relies on what macOS reports about each screen. Icons on an external display (no notch) are never marked hidden by the notch.
- Because the app is ad-hoc signed, **you may need to grant Accessibility again after each update** (remove the old entry, then add the new app).
- macOS 13 or later, Apple silicon only.

### Building from source

```sh
swift test               # run the unit tests
scripts/bundle.sh        # build Hairpin.app and Hairpin.zip
```

Needs macOS with Xcode or the Command Line Tools.

## License

MIT, see [LICENSE](LICENSE). Written from scratch; no code from other menu bar managers. A copy ships inside the app at `Hairpin.app/Contents/Resources/LICENSE`.
