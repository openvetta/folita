# Folita

纯 Swift 编写的 macOS 剪贴板工具。

## 两个面板

| 面板 | 形态 | 入口 |
| --- | --- | --- |
| 主面板 | 传统 macOS 工具布局：侧边栏分区 + 设置内容（SwiftUI `Window` + `NavigationSplitView`） | 菜单栏图标 → 打开主面板 |
| 剪贴面板 | iOS 27 Siri 新 UI 风格的通透玻璃容器，自屏幕顶部居中弹出（无边框非激活 `NSPanel`） | 菜单栏图标 → 显示剪贴面板；主面板工具栏按钮；`Esc` 关闭 |

剪贴面板的质地由 `SiriGlassContainer` 提供：Liquid Glass 打底，自上而下渐隐的着色，内容在底部淡出，边缘高光描边，底部把手。剪贴面板固定深色，取色集中在 `SiriGlassStyle`；主窗口跟随系统外观。

## 目录

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
design/app-icons/   可选应用图标的 Icon Composer 源文件（fox.icon 为默认图标）
scripts/icons/      把图标源按系统蒙层导出到 Assets.xcassets
docs/adr/           架构决策记录
docs/releasing.md   发布流程与所需凭据
project.yml         XcodeGen 工程定义（.xcodeproj 不入库）
```

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

Debug 构建可用 `open .build/DerivedData/Build/Products/Debug/Folita.app --args -FolitaShowClipboardPanel YES` 启动即弹出剪贴面板。

发布流程与所需凭据见 [docs/releasing.md](docs/releasing.md)。

## 许可证

[MIT](LICENSE) © nbecloud
