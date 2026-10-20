# 0001. 沙盒内的剪贴板监听与自动粘贴

- 状态：已采纳
- 日期：2026-10-20

## 背景

Folita 的核心闭环是「采集 → 存储 → 呼出 → 选择 → 回填」，其中回填要求选中条目后直接粘贴进用户之前的前台应用。现阶段通过 GitHub Releases 与 Homebrew 分发，但未来商业版可能上架 Mac App Store，因此应用从一开始就开启 App Sandbox（见 `Folita/Folita.entitlements`）。

两个系统边界在沙盒下是否可行需要实测：

1. **剪贴板读取**：系统没有剪贴板变化通知，只能轮询 `NSPasteboard.changeCount` 并在变化后读取内容。macOS 15.4 起有 `NSPasteboard.AccessBehavior`，SDK 头文件说明通用剪贴板默认会在程序化读取时询问用户，若对后台监听生效，每次复制都会弹窗。
2. **自动粘贴**：向前台应用发送 `⌘V` 需要 `CGEvent` 投递键盘事件，依赖辅助功能授权。

## 实测（2026-10-20，macOS 27.0.1，SDK 27.0）

用独立探针应用（沙盒、Apple Development 团队签名、`LSUIElement`）每 0.5 秒轮询 `changeCount`，变化后依次间隔 3 秒读取 `types`、读取字符串数据，最后用 `CGEvent` 向 `.cgSessionEventTap` 投递 `⌘V`。

| 项目 | 结果 |
| --- | --- |
| 全新应用启动时的 `accessBehavior` | `alwaysAllow`，而非头文件描述的 `default` |
| 轮询 `changeCount`、读取 `types` 与数据 | 均成功，全程 `alwaysAllow`，多次复制无失败 |
| 授予辅助功能后 `AXIsProcessTrusted()` | `true`（需重启进程后才读到新状态） |
| 沙盒内 `CGEvent` 投递 `⌘V` | 成功粘贴进「文本编辑/备忘录」 |

附带发现：

- macOS 27 系统设置中「辅助功能」更名为 **「设备控制和数据访问」**；`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` 仍能直达该页。
- 位于隐藏临时目录（如 `/private/tmp`）的应用加入授权列表后不显示；授权变化需重启进程才生效。
- 开源同类项目 Maccy 同样在沙盒中轮询剪贴板并用 `CGEvent` 粘贴，且未处理 `accessBehavior`。

## 决策

- 保持 App Sandbox 开启，仅声明必需的 entitlement。
- 每 0.5 秒轮询 `changeCount` 监听剪贴板，不做剪贴板访问授权的前置引导；仅当 `accessBehavior == .alwaysDeny` 时在面板与设置页提示并给出修复入口。
- 自动粘贴使用 `CGEvent` 投递 `⌘V`，默认开启；未获辅助功能授权时降级为仅写回剪贴板，并在面板中提示授权。
- 权限说明文案按系统版本区分「辅助功能」（macOS 26）与「设备控制和数据访问」（macOS 27+）；跳转链接共用。
- 判断权限状态与界面状态的映射写成纯函数，覆盖全部取值的测试。

## 备选方案

- **不开沙盒**：实现更自由，但未来上架时需迁移用户数据容器，且无法提前发现沙盒限制。放弃。
- **启动时引导剪贴板访问授权**：实测系统默认 `alwaysAllow`，前置引导只会制造打扰。放弃，保留 `.alwaysDeny` 兜底。
- **仅写回剪贴板、由用户手动 `⌘V`**：无需辅助功能，但用户普遍预期选中即粘贴。仅作为降级路径。

## 后果

- 首次使用自动粘贴需要用户手动授予辅助功能，开发调试需要稳定的代码签名（见 `Configs/Signing.xcconfig`）。
- 若未来系统真正对后台读取执行「询问」策略，需要重新评估并补充引导；`accessBehavior` 检测逻辑是该变化的入口。
- 以上结论来自单台机器的实测，系统大版本升级后应复测。
