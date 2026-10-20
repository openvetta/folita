# Folita

纯 Swift 编写的 macOS 剪贴板工具。

## 两个面板

| 面板 | 形态 | 入口 |
| --- | --- | --- |
| 主面板 | 传统 macOS 工具布局：侧边栏分区 + 设置内容（SwiftUI `Window` + `NavigationSplitView`） | 菜单栏图标 → 打开主面板 |
| 剪贴面板 | iOS 27 Siri 新 UI 风格的通透玻璃容器，自屏幕顶部居中弹出（无边框非激活 `NSPanel`） | 菜单栏图标 → 显示剪贴面板；主面板工具栏按钮；`Esc` 关闭 |

剪贴面板的质地由 `SiriGlassContainer` 提供：Liquid Glass 打底，自上而下渐隐的着色，内容在底部淡出，边缘高光描边，底部把手。深浅色外观的取色集中在 `SiriGlassStyle`。

## 目录

```text
Folita/
  App/              应用入口、AppDelegate、菜单栏菜单
  MainPanel/        主面板及其分区
  ClipboardPanel/   剪贴面板窗口、控制器、尺寸与内容
  DesignSystem/     Siri 风格玻璃容器与取色
  Resources/        Localizable.xcstrings（en / zh-Hans）
FolitaTests/        Swift Testing 单元测试
project.yml         XcodeGen 工程定义（.xcodeproj 不入库）
```

## 开发

要求 macOS 26+、Xcode 26+、[XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

```sh
make project   # 生成 Folita.xcodeproj
make build     # 构建 Debug
make test      # 运行测试
make run       # 构建并启动
```

默认使用临时签名，无需证书即可构建和测试。维护者可复制 `Configs/Local.xcconfig.example` 为 `Configs/Local.xcconfig`（不入库）并填入团队，使签名身份稳定，避免每次重新构建后辅助功能等系统授权失效。

Debug 构建可用 `open .build/DerivedData/Build/Products/Debug/Folita.app --args -FolitaShowClipboardPanel YES` 启动即弹出剪贴面板。

发布流程与所需凭据见 [docs/releasing.md](docs/releasing.md)。

## 许可证

[MIT](LICENSE) © nbecloud
