<p align="center">
  <img src="docs/assets/banner.png" alt="Folita" width="100%">
</p>

<p align="center">
  纯 Swift 编写的 macOS 剪贴板工具，拥有液态玻璃质感的剪贴面板。
</p>

<p align="center">
  <a href="README.md">English</a> ·
  简体中文 ·
  <a href="https://github.com/openvetta/folita/releases/latest">下载</a> ·
  <a href="docs/releasing.md">发布流程</a>
</p>

---

Folita 记录你复制过的内容，并用一个快捷键把它们找回来。在任何应用中按 <kbd>⌘</kbd><kbd>⇧</kbd><kbd>V</kbd>，选中一条，内容会直接粘贴回你刚才所在的应用。它只常驻菜单栏，不占用程序坞。

## 截图

<table width="100%">
  <tr>
    <td width="50%" align="center"><img src="docs/assets/screenshot-panel.png" alt="剪贴面板" width="100%"><br><sub>剪贴面板</sub></td>
    <td width="50%" align="center"><img src="docs/assets/screenshot-actions.png" alt="更多操作（⌘K）" width="100%"><br><sub>更多操作（<kbd>⌘K</kbd>）</sub></td>
  </tr>
  <tr>
    <td width="45%" align="center"><img src="docs/assets/screenshot-preview.png" alt="详情预览" width="100%"><br><sub>详情预览</sub></td>
    <td width="55%" align="center"><img src="docs/assets/screenshot-settings.png" alt="设置与应用图标" width="100%"><br><sub>设置与应用图标</sub></td>
  </tr>
</table>

## 功能

- **液态玻璃面板。** 通透的面板可从屏幕顶部、正中心或鼠标位置弹出，适配浅色与深色外观。
- **键盘优先。** <kbd>↑</kbd><kbd>↓</kbd> 选择，<kbd>↩</kbd> 粘贴，<kbd>⇧↩</kbd> 以纯文本粘贴，<kbd>⌘1</kbd>–<kbd>⌘9</kbd> 粘贴前 9 条，<kbd>⌘K</kbd> 打开更多操作。
- **搜索与筛选。** 支持文本、图片、文件、链接、颜色、邮箱，并可对选中项查看详情预览。
- **默认保护隐私。** 历史只保存在你的 Mac 上。密码管理器标记为隐藏的内容、超过 10 MB 的内容和被忽略的应用都不会被记录，也可以随时暂停记录。
- **沙盒运行。** 应用运行在 App 沙盒中，自身不申请网络权限。
- **其他。** 只常驻菜单栏（仅在设置窗口打开时出现程序坞图标）、全局快捷键、登录时启动、12 款应用图标、自动更新、中英文界面。

## 安装

要求 macOS 26 或更高版本。

```sh
brew install --cask openvetta/tap/folita
```

也可以从 [Releases](https://github.com/openvetta/folita/releases/latest) 下载已签名并经 Apple 公证的版本。

自动粘贴通过模拟 <kbd>⌘</kbd><kbd>V</kbd> 实现，需要辅助功能权限。未授权时，内容会写回剪贴板，由你手动粘贴。

## 开发

要求 macOS 26+、Xcode 26+、[XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

```sh
make project   # 生成 Folita.xcodeproj
make build     # 构建 Debug
make test      # 运行测试
make run       # 构建并启动
make app-icons # 修改 design/app-icons 后重新导出图标图片
```

默认使用临时签名，无需证书即可构建和测试。维护者可复制 `Configs/Local.xcconfig.example` 为 `Configs/Local.xcconfig`（不入库）并填入团队，使签名身份稳定，避免每次重新构建后辅助功能等系统授权失效。

让 Debug 构建启动即弹出剪贴面板：

```sh
open .build/DerivedData/Build/Products/Debug/Folita.app --args -FolitaShowClipboardPanel YES
```

### 目录

```text
Folita/
  App/              应用入口、AppDelegate（装配各服务）、菜单栏菜单、开机自启、应用图标设置
  ClipboardPanel/   剪贴面板窗口、控制器、状态模型、历史列表与搜索
  History/          剪贴板监听、采集规则、SwiftData 模型与存储、保留与隐私设置
  Paste/            写回剪贴板、自动粘贴与权限提示
  HotKey/           全局快捷键（封装 KeyboardShortcuts）
  Updates/          应用内更新（封装 Sparkle）
  MainPanel/        主面板及其设置分区
  DesignSystem/     Siri 风格玻璃容器与取色
  Resources/        Localizable.xcstrings（en / zh-Hans）、Assets.xcassets（图标缩略图，由脚本生成）
FolitaTests/        Swift Testing 单元、视图与流程测试
Configs/            签名配置（Local.xcconfig 不入库）
design/app-icons/   可选应用图标的 Icon Composer 源文件
scripts/icons/      把图标源按系统蒙层导出到 Assets.xcassets
docs/adr/           架构决策记录
docs/releasing.md   发布流程与所需凭据
project.yml         XcodeGen 工程定义（.xcodeproj 不入库）
```

## 许可证

[MIT](LICENSE) © nbecloud
