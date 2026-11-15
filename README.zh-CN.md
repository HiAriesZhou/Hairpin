[English](README.md) · **简体中文**

<p align="center">
  <img src="https://hairpin.arieszhou.com/mascot-small.webp" width="180" alt="Hairpin mascot with pink hair and a bow-shaped hairpin">
</p>

<h1 align="center">Hairpin</h1>

<p align="center">让被 MacBook 刘海挡住的菜单栏图标，随时点得到。</p>

<p align="center">
  <a href="https://github.com/HiAriesZhou/Hairpin/releases/latest/download/Hairpin.dmg"><strong>下载 Hairpin</strong></a> ·
  <a href="https://hairpin.arieszhou.com/">交互演示</a>
</p>

<p align="center">
  <a href="https://github.com/HiAriesZhou/Hairpin/releases/latest"><img src="https://img.shields.io/github/v/release/HiAriesZhou/Hairpin" alt="Latest release"></a>
  <a href="https://github.com/HiAriesZhou/Hairpin/actions/workflows/ci.yml"><img src="https://github.com/HiAriesZhou/Hairpin/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/HiAriesZhou/Hairpin" alt="MIT License"></a>
</p>

**macOS 13 及以上 · Apple 芯片 · 免费开源**

## 它做什么

菜单栏图标多到刘海旁边放不下时，Hairpin 会识别被隐藏的项目，把它们放在一行展开栏中。不用先拖动图标分组，也不用逐个设置显示规则。

- **悬停或点击展开**：鼠标停留半秒，或点击发卡，再点需要的图标即可打开对应菜单。
- **自动跟随变化**：切换应用、菜单长度变化或图标增减时，隐藏项目列表随之更新。
- **只在需要时出现**：没有隐藏项目时，不额外显示发卡；Hairpin 自己的图标可见时，由它兼作发卡。

## 安装

1. [下载 Hairpin.dmg](https://github.com/HiAriesZhou/Hairpin/releases/latest/download/Hairpin.dmg)，打开后把 Hairpin 拖到 Applications。
2. 打开 Hairpin，按提示开启「辅助功能」权限。
3. 悬停或点击发卡，访问隐藏的菜单栏项目。

正式版使用 Developer ID 签名并经过 Apple 公证，也可以从 [Releases 页面](https://github.com/HiAriesZhou/Hairpin/releases/latest)下载 ZIP。

显示真实菜单栏图标需要 macOS 14 及以上，并开启可选的屏幕录制权限。Liquid Glass 展开栏需要 macOS 26，更早的系统使用模糊背景。

## 权限与隐私

- **辅助功能（必需）**：读取菜单栏项目，并在你选择后点击对应的真实项目。
- **屏幕录制（可选，macOS 14 及以上）**：从菜单栏区域截取图标外观，图像只保存在内存中。

**不授权屏幕录制也能使用。** 展开栏会使用应用自身的图标；Apple 的项目或没有应用图标的项目使用首字母。需要真实图标时，可以在 Hairpin 菜单中选择 **Show Real Icons…**。从未显示过的图标也使用替代外观。

Hairpin 仅为检查和下载更新访问 GitHub，不发送菜单栏数据、截图、应用列表、统计数据或系统概况。GitHub 会接收 IP 地址和应用版本等常规网络信息。Hairpin 不记录按键，也不读取应用窗口内容。开启屏幕录制后，只截取菜单栏区域，并读取菜单栏项目窗口的名称。

## 更新

默认每天检查一次更新，有新版本时显示一个小圆点。右键点击发卡，选择 **Check for Updates…** 即可查看说明并安装。

**Update Automatically** 默认关闭。开启后在后台下载经过验证的更新，并在退出 Hairpin 时安装；关闭后停止自动下载，每天检查和手动检查仍然可用，已有偏好设置会保留。更新源和安装包的签名由 Sparkle 校验。

<details>
<summary>操作与设置</summary>

- **展开**：鼠标在发卡上停留半秒（移开后收起），或者点击发卡（保持展开，直到点击别处、再点一次发卡或按 Esc）。
- **顺序**：系统图标在最右边，其余按应用启动先后排列，越早启动越靠右，和菜单栏一致。
- **Hairpin 菜单**：点击 Hairpin 自己的图标（它兼当发卡时用右键），或右键点击独立发卡，可以查看隐藏图标数量、权限、悬停与登录设置、更新控制及 **Quit Hairpin**。
- **找不到 Hairpin？** 在它运行时再打开一次 Hairpin.app，被藏起来的图标会在鼠标指针处展开；没有图标被藏起来时，会弹出菜单。

</details>

## 已知限制

- Hairpin 不会移动图标，而是替你点击真实的图标。有些应用会在原来被藏起来的位置（刘海附近）弹出菜单，少数应用不响应点击，或者打开的是窗口。
- 图标的样子是在它显示时截取的，会变化的内容（未读数、电量）显示的是最后一次可见时的状态。
- 接了多块显示器时，只看带刘海的那块（没有刘海时看主屏）。

技术细节见 [How Hairpin works](docs/how-it-works.md)。

<details>
<summary>从源码构建</summary>

```sh
swift test               # 单元测试
scripts/bundle.sh        # 生成 Hairpin.app 和 Hairpin.zip（ad-hoc 签名）
scripts/test-updates.sh  # 更新设置与签名更新源验证
scripts/dmg.sh           # 再生成 Hairpin.dmg
```

需要 Xcode 或 Command Line Tools。ad-hoc 签名的构建每次重新打包后，系统授权都会失效；用 `SIGN_IDENTITY="Apple Development" scripts/bundle.sh` 以固定的证书签名，授权就能保留。

</details>

<details>
<summary>从旧版本或 NotchBar 迁移</summary>

0.2.3 及更早版本的用户，需要手动下载一次新版，才能使用应用内更新。

Hairpin 原名 NotchBar。克隆过旧仓库的开发者可以更新远程地址：

```sh
git remote set-url origin https://github.com/HiAriesZhou/Hairpin.git
```

</details>

## 贡献与许可

贡献流程见 [CONTRIBUTING.md](CONTRIBUTING.md)，安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。发布流程见 [docs/releasing.md](docs/releasing.md)。

由 AriesZhou 开发，使用 [MIT 许可](LICENSE)。代码从头编写，未使用其他菜单栏管理工具的代码；应用内附有许可证副本。
