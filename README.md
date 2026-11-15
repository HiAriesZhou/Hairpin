**English** · [简体中文](README.zh-CN.md)

<p align="center">
  <img src="https://hairpin.arieszhou.com/readme-banner.png" width="100%" alt="Hairpin: Hidden by the notch. Back within reach. App logo on the left and pink-haired mascot on the right.">
</p>

<p align="center">A tiny macOS app that brings hidden menu bar icons back within reach.</p>

<p align="center">
  <a href="https://github.com/HiAriesZhou/Hairpin/releases/latest/download/Hairpin.dmg"><strong>Download Hairpin</strong></a> ·
  <a href="https://hairpin.arieszhou.com/">Try the interactive demo</a>
</p>

<p align="center">
  <a href="https://github.com/HiAriesZhou/Hairpin/releases/latest"><img src="https://img.shields.io/github/v/release/HiAriesZhou/Hairpin" alt="Latest release"></a>
  <a href="https://github.com/HiAriesZhou/Hairpin/actions/workflows/ci.yml"><img src="https://github.com/HiAriesZhou/Hairpin/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/HiAriesZhou/Hairpin" alt="MIT License"></a>
</p>

**macOS 13+ · Apple silicon · Free and open source**

## What it does

When menu bar icons no longer fit beside the notch, Hairpin finds the hidden items and makes them available in a small row. No dragging icons into groups or setting individual visibility rules.

- **Hover or click to open.** Hover for half a second or click the hairpin, then click an item to open its menu.
- **Follows your menu bar.** The hidden-item list updates as you switch apps and icons come and go.
- **Stays out of the way.** No separate pin when nothing is hidden. When Hairpin's own icon is visible, it serves as the pin.

## Install

1. [Download Hairpin.dmg](https://github.com/HiAriesZhou/Hairpin/releases/latest/download/Hairpin.dmg), open it and drag Hairpin to Applications.
2. Open Hairpin and enable **Accessibility** when prompted.
3. Hover over or click the hairpin to reach hidden items.

Releases are Developer ID signed and notarized by Apple. A ZIP is also available on the [Releases page](https://github.com/HiAriesZhou/Hairpin/releases/latest).

Real menu bar icon images require macOS 14+ and optional Screen Recording permission. The Liquid Glass row requires macOS 26; earlier versions use a blur.

## Permissions and privacy

- **Accessibility (required):** reads menu bar items and clicks the real item when you select it.
- **Screen Recording (optional, macOS 14+):** captures icon appearances from the menu bar strip. Images stay in memory.

**Hairpin works without Screen Recording.** It uses each app's own icon instead; Apple's items and apps without an icon use an initial. To enable real icon images, choose **Show Real Icons…** in Hairpin's menu. Items that have never been visible also use the fallback.

Hairpin connects to GitHub only to check for and download updates. It sends no menu bar data, screenshots, app lists, analytics or system profile. GitHub receives ordinary network information, including your IP address and app version. Hairpin does not log keystrokes or read app-window contents. With Screen Recording enabled, it captures only the menu bar strip and reads menu bar item window names.

## Updates

By default, Hairpin checks daily and shows a small dot when an update is available. Right-click the pin and choose **Check for Updates…** to review and install it.

**Update Automatically** is off by default. Enabling it downloads verified updates in the background and installs them when Hairpin quits. Turning it off stops automatic downloads; daily and manual checks remain available. Existing preferences are preserved. Feeds and update packages are signature-verified by Sparkle.

<details>
<summary>Usage and settings</summary>

- **Open the row:** rest the pointer on the hairpin for half a second (it closes when you move away), or click it (it stays until you click elsewhere, click the hairpin again or press Escape).
- **Order:** Apple's icons on the right, the others by when their app launched, the earliest rightmost, as in the menu bar.
- **Hairpin's menu:** click Hairpin's own icon (right-click it while it's the hairpin), or right-click the separate pin, for the hidden-icon count, permissions, hover/login settings, update controls and **Quit Hairpin**.
- **Can't find Hairpin?** Open Hairpin.app again while it's running. The hidden icons drop down at the pointer, or the menu appears if none are hidden.

</details>

## Known limitations

- Hairpin doesn't move icons; it clicks the real one. Some apps open their menu by the notch, where it was hidden, and a few ignore the click or open a window instead.
- An icon's look is captured while it's shown, so anything that changes (unread counts, battery level) shows as it last looked.
- With several displays, only the notched one (or the primary one) counts.

[How Hairpin works](docs/how-it-works.md) explains the details.

<details>
<summary>Build from source</summary>

```sh
swift test               # unit tests
scripts/bundle.sh        # Hairpin.app and Hairpin.zip, ad hoc signed
scripts/test-updates.sh  # isolated update settings and signed-feed validation
scripts/dmg.sh           # then Hairpin.dmg
```

Needs Xcode or the Command Line Tools. An ad hoc build gets new privacy grants after every rebuild; `SIGN_IDENTITY="Apple Development" scripts/bundle.sh` signs it with a stable identity so they carry over.

</details>

<details>
<summary>Upgrading from an older version or NotchBar</summary>

Users of 0.2.3 and earlier need to download a current release manually once to get in-app updates.

Hairpin was formerly called NotchBar. If you cloned the old repository, update its remote:

```sh
git remote set-url origin https://github.com/HiAriesZhou/Hairpin.git
```

</details>

## Contributing and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for pull requests and [SECURITY.md](SECURITY.md) for private security reports. Release procedures are in [docs/releasing.md](docs/releasing.md).

Created by AriesZhou. [MIT licensed](LICENSE), written from scratch with no code from other menu bar managers. A copy of the license ships inside the app.
