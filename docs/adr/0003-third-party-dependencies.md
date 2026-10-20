# 0003. 第三方依赖：KeyboardShortcuts 与 Sparkle

- 状态：已采纳
- 日期：2026-10-20

## 背景

仓库规则默认不引入第三方依赖。基本功能中有两项能力自行实现成本高、边界情况多：

1. **可自定义的全局快捷键**：默认 `⌘⇧V` 呼出剪贴面板，用户可在设置中修改。注册本身（Carbon `RegisterEventHotKey`）很简单，但录制控件需要处理键盘布局（如 Dvorak）、与系统和菜单快捷键的冲突检测、只按修饰键的情况和符号显示。
2. **自动更新**：现阶段通过 GitHub Releases 与 Homebrew 分发，不经过 App Store，需要应用内检查和安装更新。

## 决策

- **[`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts)**（MIT）负责全局快捷键注册、录制控件和持久化。只在 `GlobalHotKeyService` 内部使用，其余模块和视图不直接 `import`，录制控件由设置页通过该服务提供的视图使用。
- **[Sparkle 2](https://github.com/sparkle-project/Sparkle)**（MIT 风格许可）负责自动更新。`appcast.xml` 作为 GitHub Release 附件发布，更新包用 EdDSA 签名，私钥只存放在发布环境。沙盒下按 Sparkle 文档声明安装器 XPC 所需的 `mach-lookup` 临时例外（`$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki`），与 Maccy 的做法一致。
- 两者通过 SPM 在 `project.yml` 的 `packages:` 中引入，锁定到 minor 版本，在实际集成对应功能时再加入工程。
- 除此之外仍默认不引入第三方依赖，新增依赖需另行记录。

## 备选方案

- **自写快捷键录制**：约多 400–600 行边界情况密集的代码，收益不足。放弃。
- **自写更新检查**（查询 GitHub API 并引导下载）：无法安全地自动替换应用，也缺少签名校验与增量更新。放弃。
- **只依赖 Homebrew 更新**：直接下载安装的用户无法获得更新。放弃。

## 后果

- 依赖升级需关注其 Swift 6 并发兼容性与 macOS 版本要求。
- 未来上架 App Store 的版本需在编译期移除 Sparkle 及其 entitlement 例外，由 App Store 负责更新。
- 若需替换 KeyboardShortcuts，影响范围限于 `GlobalHotKeyService`。
