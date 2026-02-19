---
summary: "Project evaluation (Feb 2026) and future development roadmap across security, performance, platform, agent, and ecosystem dimensions"
read_when:
  - Planning the next major development cycle
  - Prioritizing contributions or sponsorship areas
  - Evaluating the health and direction of OpenClaw
title: "Project Evaluation & Development Roadmap — 2026"
---

# Project Evaluation & Development Roadmap — 2026

**Date**: 2026-02-19
**Status**: Draft
**Author**: Project evaluation pass (Claude agent)
**Horizon**: Q1 2026 – Q4 2026

---

## 1. Current State Evaluation

### 1.1 What OpenClaw Is

OpenClaw is a personal AI assistant gateway that runs on user-owned devices.
It routes messages from 25+ messaging channels (WhatsApp, Telegram, Slack, Discord, iMessage, Signal, Matrix, and more) through configurable LLM providers (Anthropic, OpenAI, Google, Groq, Cerebras, AWS Bedrock, local models) and executes real tasks using a rich tool harness.

The project occupies a real gap: most "personal AI" products are cloud-hosted SaaS.
OpenClaw is deliberately terminal-first, device-local, and operator-controlled.

### 1.2 Scale

| Metric | Value (Feb 2026) |
|--------|-----------------|
| TypeScript source files | 3,242 |
| Total lines of code | ~390 K |
| Test files | 1,213 |
| Extensions (channels/providers) | 39 |
| Bundled skills | 54 |
| Direct npm dependencies | 109+ |
| Node.js minimum | 22.12.0 LTS |
| Release cadence | Multiple PRs/week |

### 1.3 Strengths

**Architecture**
- Clean channel/provider separation; adding a new LLM or messaging platform is scoped to one module.
- Plugin-first philosophy keeps core lean; optional features ship as npm packages.
- Agent harness (PI embedded runner) is capable: exec, filesystem, web, browser, image tools.
- Auto-fallback across model providers at runtime with zero config (`fallbackPolicy: "auto"`).

**Security**
- Loopback-only gateway binding by default.
- Workspace-confined filesystem tools.
- SSRF guards for all outbound fetches including cron webhooks.
- IPv6 transition-mechanism blocks (NAT64, 6to4, Teredo).
- PATH-hijack-safe binary resolution for exec tools.
- Active CVE tracking for Node.js runtime dependencies.
- Dedicated security owner with documented threat model and ATLAS.

**Ecosystem**
- 25+ channel integrations tested in production.
- iOS and Apple Watch companion apps shipping; macOS and Android in progress.
- ClawHub skill marketplace decouples skill growth from core churn.
- MCP support via `mcporter` bridge without polluting the core runtime.
- Extensive documentation (27 doc directories, Chinese translation).

**Developer Experience**
- Modern toolchain: `tsdown`, `oxlint`, `oxfmt`, `rolldown`, `tsx`, `vitest`.
- LOC limit enforced per file (500 lines) keeping modules reviewable.
- Six vitest configurations covering unit, e2e, live, gateway, and extension testing.
- Parallel CI with worker pools and secret detection.

### 1.4 Weaknesses & Risks

**Onboarding friction**
- Terminal-first setup is an intentional security tradeoff, but it creates a steep first-run experience that filters out non-technical users.
- The onboarding wizard helps, but daemon installation, model key provisioning, and channel auth are still multi-step.

**Monorepo complexity**
- 3,242 TypeScript files with 39 extensions and 54 skills create non-trivial review and synchronization overhead.
- Plugin sync script (`pnpm plugins:sync`) must be maintained manually alongside versioned packages.

**Test coverage gaps**
- Large integration surfaces (gateway server, agent harness, CLI commands, channel adapters) are intentionally excluded from unit coverage thresholds.
- This is pragmatic for a system that requires live credentials, but it means regressions can hide until e2e or manual runs.

**Memory architecture is young**
- Current memory backends (core SQLite, LanceDB, Gemini Batch) are functional but the interfaces differ.
- Workspace memory (daily Markdown logs) lacks structured recall; the v2 research design is not yet implemented.
- Only one memory plugin can be active at a time, limiting composability.

**Context compaction is heuristic**
- Session compaction strategy is configurable but not adaptive to per-model context window sizes at runtime.
- Subagent context overflow is a recurring source of agent failure reports.

**Browser tooling stability**
- `act:evaluate` blocks the Playwright per-page command queue on long-running scripts; the CDP refactor plan exists but is not yet merged.
- Browser automation is powerful but has a known class of "stuck tab" failure mode.

**Mobile parity**
- iOS companion is maturing (APNs, Watch app, Share extension, Background Listening added in 2026.2.17–18) but Android lags significantly.
- macOS native app exists; Windows and Linux desktop are not yet available.

**Windows support is secondary**
- CI worker pool reduced to 2 workers on Windows; some atomic file operations were only hardened in the last release.
- The daemon install story on Windows is less polished than macOS/Linux.

---

## 2. Development Roadmap

The following sections organize planned work by theme and rough priority horizon.
Timelines are not attached; the project moves fast when contributors appear.

### 2.1 Stability & Security (Ongoing / Highest Priority)

These always come first per VISION.md.

**Q1 2026**
- [ ] Merge the browser CDP evaluate refactor (`docs/experiments/plans/browser-evaluate-cdp-refactor.md`).
  Eliminates the stuck-evaluate / wedged-tab failure class.
- [ ] Harden PTY process supervision (see `docs/experiments/plans/pty-process-supervision.md`).
- [ ] Publish the formal verification plan for SSRF guards (`docs/security/formal-verification.md`).
- [ ] Node.js 22 LTS security patch automation (Dependabot or equivalent).
- [ ] Add integration test for `tools.exec.safeBins` PATH-hijack prevention.
- [ ] Harden cron add flows per `docs/experiments/plans/cron-add-hardening.md`.

**Ongoing**
- Channel health watchdog tuning: raise the 3-restart/hour cap when community telemetry justifies it.
- Address the 15 open `TODO` markers in source (mostly diagnostic hints, not blocking issues).
- Continue SSRF guard extension to all new outbound surfaces as channels are added.

### 2.2 Memory & Context (Q1–Q2 2026)

Memory quality directly affects agent usefulness for long-running personal workflows.

**Workspace Memory v2**
Design doc: `docs/experiments/research/memory.md`
- [ ] Implement `bank/` entity pages as Markdown source-of-truth.
- [ ] Add `## Retain` section parsing to daily memory logs (`W`, `B`, `O`, `S` prefixes).
- [ ] Build SQLite FTS5 index (`~/.openclaw/workspace/.memory/index.sqlite`) for lexical recall.
- [ ] Expose `openclaw memory recall "<query>"` CLI command with `--k`, `--since`, and `--entity` flags.
- [ ] Add a scheduled `reflect` heartbeat job that updates entity summaries and opinion confidence.
- [ ] Optional: offline embedding table for semantic recall (Ollama / bundled model).

**Context Management**
- [ ] Adaptive compaction: scale compaction threshold from resolved model `contextWindow` at runtime, not a fixed token budget.
- [ ] Surface context utilization percentage in `chat.status` and TUI so users understand when compaction is near.
- [ ] Subagent context guard: emit a structured warning before overflow; recommend re-read-with-chunks guidance automatically.

**Memory Plugin Composability**
- [ ] Allow multiple read-only memory plugins alongside one write-primary plugin.
- [ ] Define a stable `MemoryPlugin` interface version so third-party memory backends can be published to ClawHub.

### 2.3 Agent & Tool Capabilities (Q1–Q2 2026)

**Subagent Improvements**
- [ ] Deterministic subagent spawn from cron jobs (not just `/subagents spawn` chat command).
- [ ] Subagent result streaming back to parent session for long-running tasks.
- [ ] Budget-aware subagent: let parent session pass a token budget ceiling to spawned subagents.

**Browser Tooling**
- [ ] Finish CDP evaluate refactor (see §2.1).
- [ ] Add `browser.screenshotOnError` for automatic visual diagnostics on tool failure.
- [ ] Expose `act:scroll` position queries so agents can reason about page viewport state.
- [ ] Playwright version pinning strategy (lock minor, audit before upgrade).

**Exec & Sandbox**
- [ ] Docker sandbox `recreate --all` parallelism (currently serialized).
- [ ] Per-skill sandbox profiles (skill declares `requiresSandbox: true` in manifest).
- [ ] Windows exec safety: validate `safeBins` against Windows `%PATH%` semantics.

**LLM Provider Coverage**
- [ ] First-class Mistral / Cohere provider adapters (currently bridged via OpenAI-compatible endpoint).
- [ ] DeepSeek provider (demand is growing in community threads).
- [ ] Ollama provider stability: clearer error messaging for unconfigured endpoints (partially fixed 2026.2.17).
- [ ] Per-provider streaming normalization test suite to catch silent regression.

### 2.4 Platform & Native Apps (Q2–Q3 2026)

**iOS**
- [ ] StandBy / CarPlay widget surfaces for quick-send and incoming messages.
- [ ] Siri Shortcuts integration: trigger gateway actions from Shortcuts.app.
- [ ] Lock-screen notification actions (reply without unlocking).
- [ ] App Clip for frictionless pairing at new devices.

**Android**
- [ ] Bring Android companion to parity with iOS: APNs equivalent (FCM), paired device management, Share extension.
- [ ] Android Auto integration for voice-first in-car use.
- [ ] Background listening mode equivalent to iOS Talk Mode.

**macOS**
- [ ] Menu bar quick-send widget (currently only Chat panel).
- [ ] Notification Center: actionable replies from macOS notifications.
- [ ] Sparkle update channel for beta users (separate from stable appcast).

**Windows & Linux Desktop**
- [ ] Electron or Tauri desktop wrapper for Windows (gateway tray icon, quick-send).
- [ ] Linux AppImage / Flatpak / Nix flake parity for desktop sessions.
- [ ] Windows daemon installation parity with macOS LaunchAgent / Linux systemd.

### 2.5 Onboarding & UX (Q2–Q3 2026)

The terminal-first principle is correct for security, but the gap between "npm install" and "working assistant" can shrink without sacrificing it.

- [ ] `openclaw onboard` interactive TUI: show progress, detected capabilities, and suggestions.
- [ ] Single-command setup for the most common case: one model provider + one channel.
- [ ] `openclaw doctor --fix` coverage: automatically recover from all known drift states (not just token/auth drift).
- [ ] Web UI: allow read-only access to chat history and session status without requiring loopback pairing.
- [ ] First-run experience: guided example session that demonstrates tools without any config (sandbox mode).
- [ ] Configuration schema: generate typed JSON Schema docs from zod definitions for IDE autocompletion.

### 2.6 Performance & Scalability (Q2–Q3 2026)

- [ ] Gateway session store: evaluate whether SQLite WAL mode + `sqlite-vec` is sufficient at 10+ concurrent channels, or whether a lightweight local message broker is warranted.
- [ ] Tool result streaming: stream large `read` / `web_fetch` results chunk-by-chunk to the model instead of buffering the full payload.
- [ ] Model response latency telemetry: per-provider P50/P95 tracking in `openclaw model stats`.
- [ ] Memory index query latency: benchmark FTS5 vs embedding search at 10K / 100K / 1M fact scale.
- [ ] Startup time: profile and reduce cold-start latency for daemon and per-request tool invocations.
- [ ] Build time: investigate `@typescript/native-preview` for faster type-check in CI.

### 2.7 Ecosystem & Community (Ongoing)

**ClawHub**
- [ ] Publish ClawHub skill submission guidelines and review checklist.
- [ ] ClawHub skill search and one-command install: `openclaw skill add <slug>`.
- [ ] Skill version pinning in `openclaw.json` so upgrades are opt-in.
- [ ] Skill sandboxing policy: mark skills as `trusted` / `sandboxed` in manifest.

**Documentation**
- [ ] AI-generated translations for all docs (deferred per VISION.md, but tooling can be built now).
- [ ] Interactive docs: embed runnable `openclaw` examples in docs site.
- [ ] `openclaw.json` configuration reference: auto-generated from zod schema on release.
- [ ] Video onboarding series for the three most common setups (WhatsApp+Claude, Telegram+GPT, iMessage+local).

**Plugin API Stability**
- [ ] Publish stable `PluginAPI v1` contract with semantic versioning.
- [ ] Plugin compatibility matrix: list Node.js and OpenClaw version ranges per published plugin.
- [ ] `plugin.d.ts` type stubs in `dist/plugin-sdk/` shipped with every release.

---

## 3. Architecture Evolution Notes

### 3.1 Memory Convergence

The current three-backend situation (core SQLite, LanceDB, Gemini Batch) reflects different tradeoffs.
Long-term, core memory should be the default for offline-first use cases, with LanceDB as an opt-in performance upgrade.
Gemini Batch is best treated as a cloud sync/archival overlay, not a primary backend.

### 3.2 Gateway Protocol Versioning

The gateway WebSocket protocol (`bridge-protocol.md`) is used by iOS, Android, and third-party integrations.
As the native apps mature, the protocol will need a formal versioning scheme (e.g. `X-OpenClaw-Protocol: 2`) so older clients degrade gracefully.

### 3.3 Agent Hierarchy (Considered, Deferred)

VISION.md explicitly defers manager-of-managers / nested planner trees.
This is the right call for now. The subagent model (spawn, poll, budget) is sufficient for personal workflows.
Revisit if community use cases surface genuine need for multi-level delegation (e.g. project management agents).

### 3.4 MCP Runtime

MCP via `mcporter` bridge is the correct tradeoff: decoupled, low churn, avoids bloating core.
If `mcporter` becomes a maintenance burden or falls behind spec, evaluate a minimal first-class MCP transport in core as a last resort.

### 3.5 TypeScript Native Compilation

`@typescript/native-preview` is already a devDependency.
When it stabilizes, migrating type-checking to the native compiler will meaningfully improve CI times at the current codebase scale.

---

## 4. Known Technical Debt Summary

| Area | Debt | Suggested Fix |
|------|------|---------------|
| Browser | `act:evaluate` blocks Playwright queue | CDP refactor plan (see §2.1) |
| Memory | No structured recall; daily logs only | Workspace memory v2 (see §2.2) |
| Compaction | Fixed token budget, not model-adaptive | Resolve from `contextWindow` at runtime |
| Test coverage | Large integration surfaces excluded | Expand e2e matrix; add contract tests |
| Android | Lags iOS by 2+ major feature cycles | Dedicated Android sprint |
| Windows | Daemon parity, CI reduced workers | Windows-specific CI lane + installer |
| Plugin versioning | Manual sync script | Automated in pnpm workspace lifecycle |
| TODOs in source | 15 scattered annotations | Triage in next stability pass |

---

## 5. Success Metrics

Short-term (Q1 2026):
- Zero known stuck-evaluate failures after CDP refactor ships.
- `openclaw doctor --fix` resolves all documented drift states without manual steps.
- Memory v2 FTS recall in use by at least one bundled heartbeat job.

Medium-term (Q2–Q3 2026):
- Android companion reaches iOS feature parity on core flows (pair, chat, share, notifications).
- Windows daemon installation works end-to-end without manual steps.
- ClawHub has 20+ community-published skills with install tooling.
- Context utilization visible in TUI; no unhandled context overflow crashes in reported issues.

Long-term (Q4 2026+):
- OpenClaw is usable by a non-developer (with a guide) without touching a terminal.
- Plugin API v1 is stable; third-party plugins can declare compatibility ranges.
- Memory v2 with entity pages and structured recall is the default for new installs.

---

## 6. References

- [`VISION.md`](../../VISION.md) — Project priorities and contribution rules
- [`SECURITY.md`](../../SECURITY.md) — Security policy and contacts
- [`CONTRIBUTING.md`](../../CONTRIBUTING.md) — Contribution guide
- [`CHANGELOG.md`](../../CHANGELOG.md) — Release history
- [`docs/experiments/plans/browser-evaluate-cdp-refactor.md`](browser-evaluate-cdp-refactor.md) — Browser CDP plan
- [`docs/experiments/research/memory.md`](../research/memory.md) — Memory v2 research
- [`docs/security/THREAT-MODEL-ATLAS.md`](../../security/THREAT-MODEL-ATLAS.md) — Threat model
