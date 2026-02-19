# 🦞 OpenClaw — 個人 AI 助理

<p align="center">
    <picture>
        <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/openclaw/openclaw/main/docs/assets/openclaw-logo-text-dark.png">
        <img src="https://raw.githubusercontent.com/openclaw/openclaw/main/docs/assets/openclaw-logo-text.png" alt="OpenClaw" width="500">
    </picture>
</p>

<p align="center">
  <a href="https://github.com/openclaw/openclaw/actions/workflows/ci.yml?branch=main"><img src="https://img.shields.io/github/actions/workflow/status/openclaw/openclaw/ci.yml?branch=main&style=for-the-badge" alt="CI 狀態"></a>
  <a href="https://github.com/openclaw/openclaw/releases"><img src="https://img.shields.io/github/v/release/openclaw/openclaw?include_prereleases&style=for-the-badge" alt="最新版本"></a>
  <a href="https://discord.gg/clawd"><img src="https://img.shields.io/discord/1456350064065904867?label=Discord&logo=discord&logoColor=white&color=5865F2&style=for-the-badge" alt="Discord"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT 授權"></a>
</p>

**OpenClaw** 是一款部署在你自己裝置上的個人 AI 助理。
它透過你已在使用的通訊管道回應你——WhatsApp、Telegram、Slack、Discord、Google Chat、Signal、iMessage、Microsoft Teams、WebChat——以及 BlueBubbles、Matrix、Zalo、Zalo Personal 等擴充管道。它可以在 macOS／iOS／Android 上語音交談，並能渲染可互動的即時 Canvas。Gateway 只是控制平面，真正的產品是這個助理。

如果你想要一個私人、單人、感覺在地、快速且隨時在線的 AI 助理，這就是你要的。

[官網](https://openclaw.ai) · [文件](https://docs.openclaw.ai) · [願景](VISION.md) · [DeepWiki](https://deepwiki.com/openclaw/openclaw) · [快速入門](https://docs.openclaw.ai/start/getting-started) · [更新指南](https://docs.openclaw.ai/install/updating) · [展示](https://docs.openclaw.ai/start/showcase) · [FAQ](https://docs.openclaw.ai/start/faq) · [Discord](https://discord.gg/clawd)

---

## 目錄

- [特色功能](#特色功能)
- [支援的通訊管道](#支援的通訊管道)
- [支援的 AI 模型](#支援的-ai-模型)
- [快速安裝](#快速安裝)
- [快速開始](#快速開始)
- [從原始碼建置（開發者）](#從原始碼建置開發者)
- [專案結構](#專案結構)
- [開發工作流程](#開發工作流程)
- [測試](#測試)
- [發布管道](#發布管道)
- [貢獻指南](#貢獻指南)
- [安全性](#安全性)
- [授權](#授權)

---

## 特色功能

- **跨平台訊息整合**：透過單一 Gateway 接管多個通訊管道
- **多 AI 模型支援**：Anthropic Claude、OpenAI GPT、Google Gemini、AWS Bedrock、Ollama 本地模型等
- **語音互動**：macOS／iOS／Android 語音喚醒、TTS 語音回覆
- **自動化排程**：Cron 定時任務、Webhook 整合
- **記憶體系統**：可插拔的記憶體後端（LanceDB 等）
- **Canvas UI**：可渲染互動式 A2UI 介面
- **插件生態**：透過 Plugin SDK 擴充核心功能，社群插件發布於 [ClawHub](https://clawhub.ai/)
- **Skills 技能**：可自訂 AI 執行的技能腳本
- **安全優先**：SSRF 防護、exec 允許清單、DM 白名單、安全預設值

---

## 支援的通訊管道

### 內建管道

| 管道 | 說明 |
|---|---|
| WhatsApp | 透過 Baileys（WhatsApp Web） |
| Telegram | 透過 grammY bot API |
| Slack | 透過 Slack Bolt SDK |
| Discord | 透過 Carbon（Discord API） |
| Signal | 透過 signal-cli |
| iMessage | 透過 BlueBubbles 或 Apple iMessage |
| Google Chat | Webhook 整合 |
| Microsoft Teams | 透過擴充套件 |
| WebChat | 內建 Web UI |
| LINE | 透過 LINE Bot SDK |
| 飛書（Feishu） | 透過 Lark Open Platform SDK |

### 擴充管道（Extensions）

`bluebubbles`、`matrix`、`msteams`、`zalo`、`zalouser`、`irc`、`mattermost`、`nextcloud-talk`、`googlechat`、`nostr`、`tlon`、`twitch`

---

## 支援的 AI 模型

推薦使用 **Anthropic Pro/Max（100/200）+ Opus 4.6**，長上下文能力強且具備更好的 prompt 注入抗性。

- **Anthropic**：Claude Opus 4.6、Sonnet 4.6/4.5、Haiku 4.5（支援 OAuth 訂閱登入）
- **OpenAI**：GPT-4o、o3、Codex（支援 OAuth 訂閱登入）
- **Google**：Gemini 2.5 Pro／Flash
- **AWS Bedrock**：透過 IAM 認證
- **Ollama**：本地模型（Llama、Mistral 等）
- **其他**：MiniMax、Qwen、Copilot Proxy 等

---

## 快速安裝

**系統需求：Node ≥ 22**

```bash
# 使用 npm 全域安裝
npm install -g openclaw@latest

# 或使用 pnpm
pnpm add -g openclaw@latest

# 啟動引導精靈（推薦新手）
openclaw onboard --install-daemon
```

精靈會逐步引導你完成 Gateway 設定、工作區配置、通訊管道連接和技能安裝。

更多安裝方式（Docker、Nix）：
- [Docker 安裝](https://docs.openclaw.ai/install/docker)
- [Nix 安裝](https://github.com/openclaw/nix-openclaw)
- [更新指南](https://docs.openclaw.ai/install/updating)

---

## 快速開始

```bash
# 啟動 Gateway（監聽 port 18789）
openclaw gateway run --bind loopback --port 18789

# 傳送訊息
openclaw message send --to +1234567890 --message "Hello from OpenClaw"

# 向助理提問（支援高強度思考）
openclaw agent --message "幫我整理今天的工作清單" --thinking high

# 查看管道狀態
openclaw channels status --probe

# 執行診斷
openclaw doctor
```

---

## 從原始碼建置（開發者）

### 環境需求

- **Node.js 22+**（必要）
- **pnpm 10+**（建議，`npm install -g pnpm`）
- **Bun**（選用，用於加速 TypeScript 執行）

### 安裝與建置

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 安裝相依套件
pnpm install

# 建置 UI
pnpm ui:build

# 完整建置（TypeScript 編譯 + 後處理腳本）
pnpm build

# 啟動引導精靈
pnpm openclaw onboard --install-daemon
```

### 開發模式

```bash
# 以開發模式執行 CLI
pnpm openclaw <command>

# 以開發模式啟動 Gateway（跳過通訊管道）
pnpm gateway:dev

# 啟動 UI 開發伺服器
pnpm ui:dev

# 監看模式（Gateway）
pnpm gateway:watch
```

---

## 專案結構

```
openclaw/
├── src/                    # 核心 TypeScript 原始碼
│   ├── agents/             # AI Agent 執行時：模型選擇、子 Agent、沙箱、工具
│   ├── acp/                # Agent Client Protocol（ACP）整合
│   ├── browser/            # Playwright 瀏覽器自動化
│   ├── canvas-host/        # Canvas／A2UI 主機與資產
│   ├── channels/           # 管道路由與共用訊息抽象
│   ├── cli/                # CLI 指令配置、進度條、提示
│   ├── commands/           # 高階 CLI 指令實作（agent、send、hooks 等）
│   ├── config/             # 設定載入、遷移、評估
│   ├── cron/               # 排程任務執行器
│   ├── daemon/             # 背景 Daemon 程序管理
│   ├── discord/            # Discord 管道整合
│   ├── gateway/            # WebSocket Gateway 伺服器：認證、Hook、Session、HTTP
│   ├── hooks/              # 自動化 Hook（Webhook、Poll、Heartbeat、Gmail PubSub）
│   ├── imessage/           # iMessage 管道整合
│   ├── infra/              # 基礎設施：網路、Port、Bonjour/mDNS、心跳、更新
│   ├── line/               # LINE 訊息管道整合
│   ├── media/              # 媒體管道：音訊、影片、圖片處理
│   ├── memory/             # 記憶體系統（搜尋、批次處理）
│   ├── node-host/          # 節點（裝置）主機管理
│   ├── plugin-sdk/         # 公開 Plugin SDK（導出為 openclaw/plugin-sdk）
│   ├── providers/          # AI 提供商整合（OpenAI、Anthropic、Gemini、Bedrock 等）
│   ├── routing/            # 管道間訊息路由
│   ├── security/           # 安全：DM 白名單、exec 允許清單、安全路徑
│   ├── signal/             # Signal 管道整合
│   ├── slack/              # Slack 管道整合
│   ├── telegram/           # Telegram 管道整合
│   ├── terminal/           # 終端機輸出：調色盤、表格、ANSI 工具
│   ├── tui/                # 終端機 UI（TUI）介面
│   └── wizard/             # 引導精靈流程
├── extensions/             # 擴充管道插件（獨立 workspace 套件）
│   ├── bluebubbles/
│   ├── matrix/
│   ├── msteams/
│   ├── voice-call/
│   └── ...（35+ 個擴充）
├── apps/
│   ├── android/            # Android 原生應用程式（Kotlin + Jetpack Compose）
│   ├── ios/                # iOS 應用程式（Swift + SwiftUI，Alpha 版）
│   └── macos/              # macOS 選單列應用程式（Swift Package Manager）
├── ui/                     # Web 控制 UI（Lit + legacy decorators）
├── packages/               # 內部套件（clawdbot、moltbot）
├── docs/                   # 文件（Mintlify）
├── scripts/                # 開發、建置、發布輔助腳本
├── test/                   # 全域測試設定與 E2E 測試
├── dist/                   # 建置輸出（勿手動編輯）
├── AGENTS.md               # AI 助理操作指南（= CLAUDE.md）
├── CLAUDE.md               # 指向 AGENTS.md 的符號連結
├── CHANGELOG.md            # 版本更新記錄
├── CONTRIBUTING.md         # 貢獻指南
└── VISION.md               # 專案願景文件
```

### 建置系統

- **打包工具**：`tsdown`（基於 rolldown）
- **TypeScript**：嚴格模式，ESM，NodeNext 模組解析
- **主要建置進入點**（輸出至 `dist/`）：
  - `src/index.ts` — 套件主要導出
  - `src/entry.ts` — CLI 進入點
  - `src/plugin-sdk/index.ts` — Plugin SDK
  - `src/hooks/bundled/*/handler.ts` — 內建 Hook 處理器
- **Plugin SDK 路徑別名**（在 tsconfig 和 vitest 中配置）：
  - `openclaw/plugin-sdk` → `src/plugin-sdk/index.ts`

---

## 開發工作流程

### 常用指令速查

| 指令 | 說明 |
|---|---|
| `pnpm install` | 安裝所有相依套件 |
| `pnpm build` | 完整建置（TypeScript + 後處理） |
| `pnpm tsgo` | 僅執行 TypeScript 型別檢查 |
| `pnpm check` | 格式檢查 + 型別檢查 + Lint |
| `pnpm lint` | 執行 Oxlint（含型別感知） |
| `pnpm format` | 檢查格式（Oxfmt） |
| `pnpm format:fix` | 自動修正格式 |
| `pnpm test` | 執行所有測試（平行） |
| `pnpm test:fast` | 僅執行單元測試（最快） |
| `pnpm test:coverage` | 執行測試並產生覆蓋率報告 |
| `pnpm test:e2e` | 執行 E2E 測試 |
| `pnpm ui:build` | 建置 Web 控制 UI |
| `pnpm ui:dev` | 啟動 UI 開發伺服器 |

### 行動裝置開發

```bash
# Android
pnpm android:run    # 建置並安裝到已連接裝置
pnpm android:test   # 執行 Android 單元測試

# iOS（需要 XcodeGen）
pnpm ios:open       # 產生 Xcode 專案並開啟
pnpm ios:run        # 建置並在模擬器上執行

# macOS
pnpm mac:package    # 打包 macOS 應用程式
pnpm mac:restart    # 重新啟動 macOS 應用程式
```

### 程式碼風格規範

- 語言：**TypeScript（ESM）**，嚴格型別，避免 `any`
- 格式化與 Lint：透過 **Oxlint** + **Oxfmt**
- 禁止 `@ts-nocheck` 和停用 `no-explicit-any`；請修正根本原因
- 禁止透過原型突變（`applyPrototypeMixins`）共享類別行為；改用明確繼承或組合
- 命名：使用 **OpenClaw** 作為產品／App／文件標題；使用 `openclaw` 作為 CLI 指令、套件名稱、路徑和設定鍵
- 保持檔案精簡（目標 ≤700 行），可重構拆分
- 使用 `src/terminal/palette.ts` 統一 CLI 色彩調色盤，禁止硬編碼顏色

### Pre-commit Hooks

```bash
# 安裝 pre-commit hooks
prek install

# 手動執行所有 hooks
prek run --all-files
```

Hooks 包含：
- **Oxlint**：TypeScript/JavaScript Lint
- **Oxfmt**：程式碼格式化
- **SwiftLint／SwiftFormat**：Swift 程式碼（macOS／iOS）
- **detect-secrets**：防止機密資訊洩漏
- **shellcheck**：Shell 腳本 Lint
- **actionlint／zizmor**：GitHub Actions 安全審計

---

## 測試

### 測試架構

- **框架**：Vitest（V8 覆蓋率）
- **測試命名規範**：
  - `*.test.ts` — 單元測試（與原始碼同目錄）
  - `*.e2e.test.ts` — E2E 整合測試
  - `*.live.test.ts` — 需真實 API 金鑰的 Live 測試

### 覆蓋率門檻（針對 `src/` 目錄）

| 指標 | 門檻 |
|---|---|
| 行數（Lines） | 70% |
| 函式（Functions） | 70% |
| 分支（Branches） | 55% |
| 陳述式（Statements） | 70% |

### Vitest 設定檔說明

| 設定檔 | 用途 |
|---|---|
| `vitest.config.ts` | 根設定；其他設定的基底 |
| `vitest.unit.config.ts` | 純單元測試（排除 e2e、gateway、extensions） |
| `vitest.e2e.config.ts` | E2E 測試（`*.e2e.test.ts`） |
| `vitest.live.config.ts` | Live 測試（需真實 API 金鑰） |
| `vitest.gateway.config.ts` | Gateway 整合測試 |

### Live 與 Docker 測試

```bash
# Live 測試（需真實金鑰）
CLAWDBOT_LIVE_TEST=1 pnpm test:live

# Docker E2E 測試套件
pnpm test:docker:live-models     # 模型 Live 測試
pnpm test:docker:live-gateway    # Gateway Live 測試
pnpm test:docker:onboard         # 引導流程 E2E 測試
pnpm test:docker:plugins         # 插件測試
pnpm test:install:smoke          # 安裝煙霧測試
```

---

## 發布管道

| 管道 | 說明 | npm 標籤 |
|---|---|---|
| **stable** | 標籤版本（`vYYYY.M.D`） | `latest` |
| **beta** | 預發布版本（`vYYYY.M.D-beta.N`） | `beta` |
| **dev** | `main` 分支最新 HEAD | `dev` |

```bash
# 切換發布管道
openclaw update --channel stable
openclaw update --channel beta
openclaw update --channel dev
```

版本號碼分布在以下位置：
- `package.json`（CLI）
- `apps/android/app/build.gradle.kts`
- `apps/ios/Sources/Info.plist`
- `apps/macos/Sources/OpenClaw/Resources/Info.plist`

---

## 貢獻指南

歡迎提交 Pull Request！詳見 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 提交 PR 前

1. 在本地以自己的 OpenClaw 實例測試
2. 執行：`pnpm build && pnpm check && pnpm test`
3. 確保 CI 通過
4. 保持 PR 單一主題（一個 PR 對應一個問題）

### 提交訊息格式

採用簡潔的行動導向格式：

```
CLI: add verbose flag to send
agents(anthropic): support 1M context beta header
fix(security): block NAT64 SSRF bypass via IPv6 transition addresses
```

使用 `scripts/committer "<msg>" <file...>` 建立提交，避免手動 `git add`。

### AI 輔助 PR

使用 Claude、Codex 等 AI 工具建置的 PR 受歡迎！請在 PR 中標注：
- AI 輔助程度
- 測試覆蓋範圍（未測試／輕度測試／完整測試）
- 提示詞或 Session 記錄（非常有幫助）

---

## 安全性

OpenClaw 的安全設計是在能力與預設安全之間刻意取得平衡。

- **漏洞回報**：透過 GitHub 安全諮詢回報，或寄信至 security@openclaw.ai
- **受影響範圍**：
  - 核心 CLI／Gateway → [openclaw/openclaw](https://github.com/openclaw/openclaw)
  - macOS App → `apps/macos`
  - iOS App → `apps/ios`
  - Android App → `apps/android`
  - ClawHub → [openclaw/clawhub](https://github.com/openclaw/clawhub)

漏洞回報需包含：標題、嚴重性評估、影響範圍、受影響元件、技術重現步驟、已驗證的影響、環境資訊、修復建議。

詳見 [SECURITY.md](SECURITY.md)。

---

## 授權

本專案採用 [MIT 授權](LICENSE)。

---

## 相關連結

- [官方網站](https://openclaw.ai)
- [完整文件](https://docs.openclaw.ai)
- [Discord 社群](https://discord.gg/clawd)
- [GitHub Issues](https://github.com/openclaw/openclaw/issues)
- [GitHub Discussions](https://github.com/openclaw/openclaw/discussions)
- [ClawHub（社群技能）](https://clawhub.ai/)
- [DeepWiki 程式碼解析](https://deepwiki.com/openclaw/openclaw)
- [X / Twitter @openclaw](https://x.com/openclaw)
