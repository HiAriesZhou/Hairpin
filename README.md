# Hairpin

<p align="center"><img src="docs/icon.png" width="128" height="128" alt="Hairpin's icon: a pink bow on a bobby pin"></p>

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

在带刘海的 MacBook 上，菜单栏右侧空间有限。图标一多，macOS 会把放不下的图标藏起来：它们被挤到刘海后面或刘海左侧，系统不再绘制，没有任何提示，也点不到。

Hairpin 只在这种时候出现：菜单栏里有图标被挤掉时，可见图标的最左端会出现一个小发卡（蝴蝶结发夹图标），被挤掉的图标都收在它里面。悬停或点击发卡，下方会展开一行，显示这些图标；点其中一个，就会打开它本来的菜单。没有图标被挤掉时，发卡不会出现。

### 安装

1. 从 [Releases](https://github.com/HiAriesZhou/Hairpin/releases) 下载 `Hairpin.dmg`，打开后把 `Hairpin.app` 拖到旁边的「Applications」文件夹；或者下载 `Hairpin.zip`，解压后把 `Hairpin.app` 拖进「应用程序」。
2. 这个应用是 ad-hoc 签名，没有经过 Apple 公证，第一次打开会被 Gatekeeper 拦下。两种办法任选一种：
   - 在 Finder 里**右键（或按住 Control 点按）Hairpin.app → 打开**，在弹出的对话框里再点「打开」；
   - 或者在终端执行：
     ```sh
     xattr -dr com.apple.quarantine /Applications/Hairpin.app
     ```
3. 系统要求：macOS 13 Ventura 或更高版本，Apple 芯片（arm64）。发布的是 arm64 版本，不是通用二进制；带刘海的 Mac 都是 Apple 芯片。

### 权限

- **辅助功能（必需）**：Hairpin 用辅助功能 API 读取其他应用的菜单栏图标，并替你「点击」它们。第一次运行会弹窗说明，点「Open System Settings」后，在「系统设置 › 隐私与安全性 › 辅助功能」里打开 Hairpin。如果列表里没有它，点「+」手动添加 `Hairpin.app`。授权之前，菜单里只有「Grant Accessibility…」、「Open on Hover」、「Launch at Login」和「Quit Hairpin」。
- **屏幕录制（可选，macOS 14 及以上）**：用来显示图标在菜单栏上的真实样子，并准确识别每个窗口属于哪个应用。第一次有图标被挤掉并展开时，系统会请求授权；也可以从菜单里的「Show Real Icons…」授权。不授权也能用：图标会显示为圆角方框里的应用首字母，识别改用位置推算。Hairpin 只截取菜单栏这一条，只在出现新的可见图标时截一次，截图只保存在内存里；截图时 macOS 可能短暂显示录屏指示。
- **从旧版 NotchBar 升级**：Bundle ID 已从 `com.hiarieszhou.notchbar` 改为 `com.hiarieszhou.hairpin`，macOS 把它当作一个新应用，旧版的辅助功能授权和登录项都不会沿用。请在「辅助功能」里重新为 Hairpin.app 打开授权，需要的话重新勾选「Launch at Login」；旧的 NotchBar 条目可以用「−」删掉。

Hairpin 不联网，不记录按键，也不读取应用窗口的内容。授予屏幕录制后，它只截取菜单栏这一条来抠出图标形状，并读取菜单栏图标窗口的名称来识别所属应用；图标形状只保存在内存里。

### 使用

- **发卡**：有图标被挤掉时，出现在可见图标的最左端，也就是下一个图标本该在的位置；如果那里被前台应用的长菜单占满，就放到刘海左侧，或者戴上一个小胶囊盖住最左边的可见图标（被盖住的图标也一并收进去）。切换应用、菜单栏里出现或消失图标时，位置都会重新计算（每秒检查一次菜单栏）。菜单栏自动隐藏或处于全屏时，发卡随菜单栏一起隐藏。Hairpin 自己的图标正好是最左边那个时，它本身就是发卡。
- **打开**：
  - 悬停在发卡上 0.5 秒：展开，鼠标离开后收起；
  - 点击发卡：展开并保持，直到点击别处、再点一次发卡或按 Esc。
- **展开的一行**：图标按菜单栏的规则排列，系统图标在最右边，其余按应用启动先后，越早启动越靠右。点一个图标，会替你点击它本来的图标，应用的菜单随之弹出；这一行会保持打开，点别处才收起。
- **Hairpin 的菜单**：点击 Hairpin 图标（它兼当发卡时用右键或按住 Control 点按）：
  - 第一行显示有几个图标被挤掉；
  - **Show Real Icons…**：授予屏幕录制权限（未授权时显示）；
  - **Open on Hover**：悬停是否展开，默认开启；关掉后只能点击展开；
  - **Launch at Login**：登录时自动启动（使用 `SMAppService`）。如果 macOS 要求你批准，这一项会显示为「–」，点它会打开「系统设置 › 通用 › 登录项」；
  - **Quit Hairpin**：退出。
- 如果找不到 Hairpin：在它运行时，从访达、聚焦搜索或启动台再打开一次 Hairpin.app，被挤掉的图标会直接展开（没有发卡时，比如菜单栏自动隐藏了，就在鼠标指针处展开）；没有图标被挤掉时，菜单会在鼠标指针处弹出。

### 工作原理

1. 在后台线程遍历正在运行的应用，对每个应用调用 `AXUIElementCreateApplication(pid)`，读取 `AXExtrasMenuBar` 的子元素（`AXMenuBarItem`），也就是它的菜单栏图标，以及它们的标题、描述、位置和大小。启动时、应用启动/退出/切换时（切换后 0.4 秒再读一次，等新应用的菜单就位）、切换空间和屏幕变化时都会重新读取。
2. 用 `CGWindowListCopyWindowInfo` 读取所有菜单栏图标窗口。在 macOS 26 上，被挤掉的图标窗口仍在那一排里，只是被系统标为不显示，这个标记就是判断依据。每块屏幕的菜单栏各有一排窗口；授予屏幕录制后，当前活跃那块屏幕上的窗口以所属应用的 Bundle ID 命名，Hairpin 按名称把窗口对应到应用，再找到它在刘海屏上那一份。没有名称时，按位置和宽度推算。辅助功能里尺寸为 0 的条目（比如控制中心里没显示的模块）会被丢掉。在更早的系统上，与刘海重叠或在刘海左侧被应用菜单盖住的图标，也算被挤掉。
3. 有屏幕录制权限时，在图标可见时截一次整条菜单栏：一张正常截图，一张排除菜单栏窗口后的截图，两者相减，抠出图标的形状，作为模板图标显示，跟随系统的深浅色。被挤掉的图标系统不绘制，所以显示的是它最后一次可见时的样子。
4. 你点一个图标后，Hairpin 对那个真实的图标执行 `AXPress`，不支持时改用 `AXShowMenu`，于是应用自己的菜单就打开了。

判断、排序和摆放位置的逻辑在独立的 `HairpinCore` 模块里，有单元测试（`swift test`）。

### 已知限制

- **不会真正移动图标。** Hairpin 不改变图标在菜单栏上的位置，只是替你点击它。
- **菜单可能出现在刘海附近。** 菜单是应用自己弹出的，位置跟着真实图标走，而被挤掉的图标就在刘海附近。有些应用的菜单会贴着刘海弹出，部分内容可能被挡住或被挤到一边。
- 有些应用的图标不响应 `AXPress` / `AXShowMenu`，或者点了之后打开的是自定义窗口而不是菜单，这取决于应用自己的实现。
- 图标的样子是缓存的：会变化的内容（比如未读数、电量）显示的是最后一次可见时的状态。从 Hairpin 启动起就一直被挤掉的图标，没机会截图，显示为圆角方框里的应用首字母（悬停可看到应用名），等它下次显示出来再换成真实样子。截到的图标是单色的，彩色的菜单栏图标会变成单色。
- 未响应的应用会被跳过：每个辅助功能请求的超时是 0.25 秒，而且读取在后台进行，所以卡住的应用只会让它自己的图标不出现，不会卡住 Hairpin。
- 接了多块显示器时，只关心带刘海的那块（没有刘海时是主屏）；没有被激活过的菜单栏，系统可能不会立刻重新排列。
- 应用采用 ad-hoc 签名，**每次更新到新版本后，可能需要在「辅助功能」和「屏幕录制」里重新授权**（先删掉旧条目再添加）。
- 只支持 macOS 13 及以上、Apple 芯片的 Mac；显示真实图标需要 macOS 14 及以上；Liquid Glass 外观需要 macOS 26，更早的系统用毛玻璃。

### 从源码构建

```sh
swift test               # 运行单元测试
scripts/bundle.sh        # 生成 Hairpin.app 和 Hairpin.zip（含应用图标）
scripts/dmg.sh           # 再把 Hairpin.app 打成 Hairpin.dmg
```

需要安装 Xcode 或 Command Line Tools 的 macOS。本地调试时，可以用固定的签名身份打包，这样重新构建后系统授权不会失效：

```sh
SIGN_IDENTITY="Apple Development" scripts/bundle.sh
```

---

## English

### The problem

On a notched MacBook the right side of the menu bar is short. When there are too many menu bar icons, macOS hides the ones that don't fit: they're pushed behind the notch or to its left and no longer drawn. They vanish without a trace, and you can't click them.

Hairpin only shows up when that happens. While icons are hidden, a little hairpin (a bow on a bobby pin) appears at the left end of the shown icons, holding the hidden ones. Hover over it or click it and a row of those icons drops down below; click one and its own menu opens. With nothing hidden, the hairpin isn't there.

### Install

1. Download `Hairpin.dmg` from [Releases](https://github.com/HiAriesZhou/Hairpin/releases), open it and drag `Hairpin.app` onto the Applications folder beside it; or download `Hairpin.zip`, unzip it and drag `Hairpin.app` into Applications.
2. The app is ad-hoc signed and not notarized, so Gatekeeper blocks the first launch. Either:
   - **Right-click (or Control-click) Hairpin.app in Finder → Open**, then click Open in the dialog; or
   - run:
     ```sh
     xattr -dr com.apple.quarantine /Applications/Hairpin.app
     ```
3. Requires macOS 13 Ventura or later on Apple silicon (arm64). The release is an arm64 build, not a universal one; every notched Mac is Apple silicon.

### Permissions

- **Accessibility (required).** Hairpin reads other apps' menu bar icons and "clicks" them through the Accessibility API. On first launch an alert explains this; click "Open System Settings" and turn on Hairpin under System Settings › Privacy & Security › Accessibility. If it isn't listed, click "+" and add `Hairpin.app`. Until you grant it, the menu shows only "Grant Accessibility…", "Open on Hover", "Launch at Login" and "Quit Hairpin".
- **Screen Recording (optional, macOS 14 or later).** It lets Hairpin show icons as they look in the menu bar and tell exactly which app each one belongs to. macOS asks for it the first time hidden icons are opened, or grant it from "Show Real Icons…" in the menu. Without it Hairpin still works: icons show as the app's initial in a rounded square, and it works out which icon is which from positions. Hairpin captures only the menu bar strip, once when new icons show up, and keeps the captures in memory; macOS may briefly show its recording indicator while it does.
- **Upgrading from NotchBar.** The bundle ID changed from `com.hiarieszhou.notchbar` to `com.hiarieszhou.hairpin`, so macOS treats Hairpin as a new app and the old Accessibility and Login Items grants don't carry over. Turn Accessibility on again for Hairpin.app, and re-enable "Launch at Login" if you used it. You can remove the old NotchBar entry with "−".

Hairpin makes no network connections, doesn't log keystrokes and doesn't read app windows' contents. With Screen Recording it captures only the menu bar strip, to cut out icon shapes, and reads menu bar item windows' names to tell which app each belongs to; the shapes are kept in memory only.

### Usage

- **The hairpin** appears while icons are hidden, at the left end of the shown icons, where the next one would have gone. If the frontmost app's long menus fill that spot, it moves left of the notch, or puts on a small capsule and sits on the leftmost shown icon, which it then holds too. It moves as you switch apps and as icons come and go (it checks the menu bar every second). While the menu bar is hidden (auto-hide, full screen), so is the hairpin. When Hairpin's own icon is the leftmost one, that icon is the hairpin.
- **Opening it:**
  - rest the pointer on it for half a second: the row opens, and closes when the pointer leaves;
  - click it: the row opens and stays until you click elsewhere, click the hairpin again or press Escape.
- **The row** orders icons as the menu bar does: Apple's on the right, the rest by launch, earliest launched rightmost. Click an icon and Hairpin clicks the real one, so the app opens its menu; the row stays open until you click elsewhere.
- **Hairpin's menu**, from a click on Hairpin's icon (a right-click or Control-click while that icon is the hairpin):
  - the first line says how many icons are hidden;
  - **Show Real Icons…** grants Screen Recording (shown until it's granted);
  - **Open on Hover** turns hover opening on or off (on by default; off, only a click opens the row);
  - **Launch at Login** starts Hairpin when you log in (via `SMAppService`). If macOS asks for approval, the item shows a dash and opens System Settings › General › Login Items;
  - **Quit Hairpin** quits.
- If you can't find Hairpin, open Hairpin.app again while it's running (Finder, Spotlight or Launchpad). The hidden icons drop down, at the pointer when there's no hairpin (say the menu bar is hidden); with none hidden, the menu pops up at the pointer.

### How it works

1. On a background thread, for each running app, Hairpin calls `AXUIElementCreateApplication(pid)` and reads the children (`AXMenuBarItem`) of its `AXExtrasMenuBar`: the app's menu bar icons, with their titles, descriptions, positions and sizes. It rescans at launch, when apps launch, quit or switch (and again 0.4 s after a switch, once the new app's menus are in), when spaces change and when screens change.
2. It lists every menu bar icon window with `CGWindowListCopyWindowInfo`. On macOS 26 a hidden icon's window stays in the row but is marked as not shown, and that mark is what counts. Each screen's menu bar has its own row of windows; with Screen Recording, the windows on the active menu bar are named after their app's bundle ID, so Hairpin matches windows to apps by name, then finds each one's copy on the notched screen. Without names it goes by position and width. Accessibility elements with no size (such as Control Center modules that aren't shown) are dropped. On earlier systems, icons that overlap the notch, or sit left of it under the app's menus, count as hidden too.
3. With Screen Recording, it captures the menu bar strip once while an icon is shown: once as is and once without the menu bar's windows. The difference is the icon's shape, shown as a template image in the system's light or dark look. macOS doesn't draw hidden icons, so they show as they last looked.
4. When you click an icon, Hairpin performs `AXPress` on the real one, or `AXShowMenu` if it doesn't support `AXPress`, and the app opens its own menu.

The classification, ordering and placement logic lives in a separate `HairpinCore` module with unit tests (`swift test`).

### Known limitations

- **It doesn't physically move icons.** Hairpin leaves each icon where it is in the menu bar and just clicks it for you.
- **Menus can open near the notch.** The app opens its own menu at the real icon's position, and hidden icons sit by the notch. Some apps' menus open against the notch and may be partly hidden or pushed aside.
- Some icons don't respond to `AXPress` / `AXShowMenu`, or open a custom window instead of a menu. That depends on how each app is built.
- Icon looks are cached: anything that changes (unread counts, battery level) shows as it last looked. An icon that's been hidden since Hairpin started was never captured and shows as its app's initial in a rounded square (hover for the name) until it next shows. Captures are monochrome, so a colored menu bar icon turns monochrome.
- Unresponsive apps are skipped. Every Accessibility request has a 0.25 s timeout and the scan runs in the background, so a hung app only leaves its own icons out; it can't freeze Hairpin.
- With several displays, only the notched one counts (the primary one if none is notched). macOS may not relay out a menu bar that hasn't been active.
- Because the app is ad-hoc signed, **you may need to grant Accessibility and Screen Recording again after each update** (remove the old entry, then add the new app).
- macOS 13 or later, Apple silicon only; real icons need macOS 14; the Liquid Glass look needs macOS 26, with a blur before it.

### Building from source

```sh
swift test               # run the unit tests
scripts/bundle.sh        # build Hairpin.app (with its icon) and Hairpin.zip
scripts/dmg.sh           # then wrap Hairpin.app into Hairpin.dmg
```

Needs macOS with Xcode or the Command Line Tools. For local builds, a fixed signing identity keeps the privacy grants across rebuilds:

```sh
SIGN_IDENTITY="Apple Development" scripts/bundle.sh
```

## Contributing and security

Contributions are welcome through pull requests; see [CONTRIBUTING.md](CONTRIBUTING.md). Report security issues privately as described in [SECURITY.md](SECURITY.md).

欢迎通过 PR 贡献，流程见 [CONTRIBUTING.md](CONTRIBUTING.md)；安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。

## License

MIT, see [LICENSE](LICENSE). Written from scratch; no code from other menu bar managers. A copy ships inside the app at `Hairpin.app/Contents/Resources/LICENSE`.
