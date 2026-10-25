# NotchBar

[![CI](https://github.com/HiAriesZhou/NotchBar/actions/workflows/ci.yml/badge.svg)](https://github.com/HiAriesZhou/NotchBar/actions/workflows/ci.yml)

A tiny macOS menu bar app that lets you reach the menu bar icons hidden behind the MacBook notch.
一个极简的 macOS 菜单栏小工具：让你点得到被 MacBook 刘海挡住的菜单栏图标。

[中文](#中文) · [English](#english)

---

## 中文

### 解决什么问题

在带刘海的 MacBook 上，菜单栏右侧空间有限。图标一多，macOS 会把放不下的图标排到刘海后面或刘海左侧，那里会被前台应用的菜单盖住。这些图标没有任何提示，也点不到。

NotchBar 只做一件事：在菜单栏放一个图标，点开后列出所有其他应用的菜单栏图标，被刘海挡住的排在最前面。点一下列表里的某一项，就会打开那个图标本来的菜单。

### 安装

1. 从 [Releases](https://github.com/HiAriesZhou/NotchBar/releases) 下载 `NotchBar.zip`，解压后把 `NotchBar.app` 拖进「应用程序」。
2. 这个应用是 ad-hoc 签名，没有经过 Apple 公证，第一次打开会被 Gatekeeper 拦下。两种办法任选一种：
   - 在 Finder 里**右键（或按住 Control 点按）NotchBar.app → 打开**，在弹出的对话框里再点「打开」；
   - 或者在终端执行：
     ```sh
     xattr -dr com.apple.quarantine /Applications/NotchBar.app
     ```
3. 系统要求：macOS 13 Ventura 或更高版本。

### 权限

- **辅助功能（必需）**：NotchBar 用辅助功能 API 读取其他应用的菜单栏图标，并替你「点击」它们。第一次运行会弹窗说明，点「Open System Settings」后，在「系统设置 › 隐私与安全性 › 辅助功能」里打开 NotchBar。如果列表里没有它，点「+」手动添加 `NotchBar.app`。授权之前，菜单里只有一项「Grant Accessibility…」。
- **屏幕录制**：不需要。NotchBar 显示的是应用图标，不截取菜单栏画面。

NotchBar 不联网，不读取窗口内容，也不记录按键。

### 使用

- 点击菜单栏里的 NotchBar 图标，弹出列表：
  - **Hidden by the notch**：被刘海挡住、位于刘海左侧或在屏幕外的图标；
  - **Visible**：当前能看到的图标；
  - 读不到位置的图标排在最后。
- 点击某一项，会打开对应图标的菜单。
- **Launch at Login**：登录时自动启动（使用 `SMAppService`）。
- **Quit NotchBar**：退出。

### 工作原理

1. 遍历正在运行的应用，对每个应用调用 `AXUIElementCreateApplication(pid)`，读取 `AXExtrasMenuBar` 属性，它的子元素（`AXMenuBarItem`）就是这个应用的菜单栏图标。同时读取标题、描述、位置和大小。
2. 用 `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 算出刘海的位置。图标与刘海重叠，或在刘海屏的顶部一行里位于刘海左侧，就判定为被刘海挡住；大部分不在任何屏幕上的，判定为在屏幕外。
3. 你选中某一项后，NotchBar 对那个真实的图标执行 `AXPress`，不支持时改用 `AXShowMenu`，于是应用自己的菜单就打开了。

判断与排序逻辑在独立的 `NotchBarCore` 模块里，有单元测试（`swift test`）。

### 已知限制

- **不会真正移动图标。** NotchBar 不改变图标在菜单栏上的位置，只是替你点击它。
- **菜单可能出现在刘海下面。** 菜单是应用自己弹出的，位置跟着真实图标走。如果图标在刘海后面，有些应用的菜单会贴着刘海弹出，部分内容可能被挡住或被挤到一边。
- 有些应用的图标不响应 `AXPress` / `AXShowMenu`，或者点了之后打开的是自定义窗口而不是菜单，这取决于应用自己的实现。
- 有些图标没有标题或描述，列表里只显示应用名；同一个应用有多个图标时，可能很难区分。
- 未响应的应用会被跳过（每个应用的读取超时是 0.25 秒）。
- 刘海判断依赖系统提供的屏幕信息。外接显示器（没有刘海）上不会把图标标成「被挡住」。
- 应用采用 ad-hoc 签名，**每次更新到新版本后，可能需要在「辅助功能」里重新授权**（先删掉旧条目再添加）。
- 只支持 macOS 13 及以上。

### 从源码构建

```sh
swift test               # 运行单元测试
scripts/bundle.sh        # 生成 NotchBar.app 和 NotchBar.zip
```

需要安装 Xcode 或 Command Line Tools 的 macOS。

---

## English

### The problem

On a notched MacBook the right side of the menu bar is short. When there are too many menu bar icons, macOS lays the extra ones out behind the notch or to its left, where the frontmost app's menus cover them. They vanish without a trace, and you can't click them.

NotchBar does one thing. It puts an icon in the menu bar; click it to list every other app's menu bar icon, with the ones hidden by the notch at the top. Pick an entry and that icon's own menu opens.

### Install

1. Download `NotchBar.zip` from [Releases](https://github.com/HiAriesZhou/NotchBar/releases), unzip it and drag `NotchBar.app` into Applications.
2. The app is ad-hoc signed and not notarized, so Gatekeeper blocks the first launch. Either:
   - **Right-click (or Control-click) NotchBar.app in Finder → Open**, then click Open in the dialog; or
   - run:
     ```sh
     xattr -dr com.apple.quarantine /Applications/NotchBar.app
     ```
3. Requires macOS 13 Ventura or later.

### Permissions

- **Accessibility (required).** NotchBar reads other apps' menu bar icons and "clicks" them through the Accessibility API. On first launch an alert explains this; click "Open System Settings" and turn on NotchBar under System Settings › Privacy & Security › Accessibility. If it isn't listed, click "+" and add `NotchBar.app`. Until you grant it, the menu shows only "Grant Accessibility…".
- **Screen Recording: not needed.** NotchBar shows app icons and doesn't capture the menu bar.

NotchBar makes no network connections, doesn't read window contents and doesn't log keystrokes.

### Usage

- Click the NotchBar icon in the menu bar:
  - **Hidden by the notch**: icons behind the notch, to its left, or offscreen;
  - **Visible**: icons you can already see;
  - icons that report no position come last.
- Click an entry to open that icon's menu.
- **Launch at Login** starts NotchBar when you log in (via `SMAppService`).
- **Quit NotchBar** quits.

### How it works

1. For each running app, NotchBar calls `AXUIElementCreateApplication(pid)` and reads the `AXExtrasMenuBar` attribute. Its children (`AXMenuBarItem`) are the app's menu bar icons. It also reads each icon's title, description, position and size.
2. It works out where the notch is from `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`. An icon that overlaps the notch, or sits left of it in the top row of a notched screen, counts as hidden by the notch. One that's mostly off every screen counts as offscreen.
3. When you pick an entry, NotchBar performs `AXPress` on the real icon, or `AXShowMenu` if the icon doesn't support `AXPress`, and the app opens its own menu.

The classification and sorting logic lives in a separate `NotchBarCore` module with unit tests (`swift test`).

### Known limitations

- **It doesn't physically move icons.** NotchBar leaves each icon where it is in the menu bar and just clicks it for you.
- **Menus can open under the notch.** The app opens its own menu at the real icon's position. When that icon is behind the notch, some apps' menus open against the notch and may be partly hidden or pushed aside.
- Some icons don't respond to `AXPress` / `AXShowMenu`, or open a custom window instead of a menu. That depends on how each app is built.
- Some icons have no title or description, so the list shows only the app name, and several icons from the same app can be hard to tell apart.
- Unresponsive apps are skipped (0.25 s Accessibility timeout per app).
- Notch detection relies on what macOS reports about each screen. Icons on an external display (no notch) are never marked hidden by the notch.
- Because the app is ad-hoc signed, **you may need to grant Accessibility again after each update** (remove the old entry, then add the new app).
- macOS 13 or later only.

### Building from source

```sh
swift test               # run the unit tests
scripts/bundle.sh        # build NotchBar.app and NotchBar.zip
```

Needs macOS with Xcode or the Command Line Tools.

## License

MIT, see [LICENSE](LICENSE). Written from scratch; no code from other menu bar managers.
