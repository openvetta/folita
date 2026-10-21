# 发布 Folita

推送 `v<版本号>` tag 会触发 [`.github/workflows/release.yml`](../.github/workflows/release.yml)：校验版本与发布说明 → Developer ID 签名 → 公证并 staple → 打包 zip → 生成 Sparkle `appcast.xml` → 发布 GitHub Release（正文取自 `.github/release-notes/v<版本号>.md`）→ 更新 Homebrew tap。

不经过 App Store Connect 与 TestFlight。

## 一次性准备

在 GitHub 仓库 **Settings › Secrets and variables › Actions** 中配置：

| 类型 | 名称 | 内容 |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | 开发者团队 ID |
| Secret | `DEVELOPER_ID_CERTIFICATE_P12` | Developer ID Application 证书（含私钥）导出的 `.p12`，再 `base64` 编码 |
| Secret | `DEVELOPER_ID_CERTIFICATE_PASSWORD` | 导出 `.p12` 时设置的密码 |
| Secret | `APPLE_API_KEY_P8` | 公证用 App Store Connect API Key 的 `.p8` 文件全文 |
| Variable | `APPLE_API_KEY_ID` | 该 API Key 的 Key ID |
| Variable | `APPLE_API_ISSUER_ID` | App Store Connect 的 Issuer ID |
| Variable | `SPARKLE_PUBLIC_ED_KEY` | Sparkle EdDSA 公钥 |
| Secret | `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA 私钥 |
| Secret | `HOMEBREW_TAP_TOKEN` | 可写 `openvetta/homebrew-tap` 的 fine-grained token；不配置则跳过更新 tap |

### 证书

Xcode › Settings › Accounts › Manage Certificates › `+` › **Developer ID Application**（需要团队 Account Holder 权限）。在「钥匙串访问」中导出该证书为 `.p12`，然后：

```sh
base64 -i DeveloperID.p12 | pbcopy
```

### Sparkle 密钥

构建过一次工程后，Sparkle 工具位于 `.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/`：

```sh
SPARKLE_BIN=.build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
$SPARKLE_BIN/generate_keys            # 生成密钥对，私钥保存在登录钥匙串，输出公钥
$SPARKLE_BIN/generate_keys -x sparkle_private_key   # 导出私钥，填入 SPARKLE_PRIVATE_KEY 后删除该文件
```

公钥同时写入 `project.yml` 的 `SPARKLE_PUBLIC_ED_KEY`，本地构建才会启用应用内更新。**私钥一旦丢失，已安装的用户将无法再收到更新**，请妥善备份。

### Homebrew tap

在 GitHub 组织 `openvetta` 下创建公开仓库 `homebrew-tap`。发布后用户可通过以下命令安装：

```sh
brew install --cask openvetta/tap/folita
```

Cask 模板见 [`packaging/homebrew/folita.rb`](../packaging/homebrew/folita.rb)。

## 每次发布

1. 确认 `project.yml` 的 `MARKETING_VERSION` 已更新，`.github/release-notes/v<版本号>.md` 已写好：`make check-release-notes`。
2. 推送 tag：`git tag v0.1.0 && git push origin v0.1.0`。tag 与 `MARKETING_VERSION` 不一致时流水线会中止。构建号（`CURRENT_PROJECT_VERSION`）由流水线按版本号推导（主×10000 + 次×100 + 修订），Sparkle 靠它判断更新，无需手工维护。

## 手动发布（不使用流水线）

Xcode › Product › Archive › Distribute App › **Direct Distribution**，Xcode 会完成签名、公证与 staple。之后需要手动用 `generate_appcast` 生成 appcast、创建 GitHub Release，并更新 tap 中的 cask。
