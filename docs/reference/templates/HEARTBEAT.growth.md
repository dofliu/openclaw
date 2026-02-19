---
title: "HEARTBEAT.md Growth Edition"
summary: "Heartbeat checklist designed for agent growth — reflection, distillation, skill tracking"
read_when:
  - Setting up a new workspace for agent growth
  - Replacing a minimal HEARTBEAT.md with a growth-oriented version
---

# Heartbeat Checklist（成長版）

> 把這個檔案命名為 `HEARTBEAT.md` 放在 workspace 根目錄。
> Heartbeat 每次觸發時會讀取並執行此清單。

---

## 每次觸發（Every heartbeat）

```
1. 掃描是否有未讀的重要訊息或緊急事項
   → 有緊急事項：回覆處理
   → 沒有：繼續往下

2. 檢查是否有進行中的任務卡住
   → 若卡住：記錄到 memory/YYYY-MM-DD.md，等下次對話問使用者

3. 沒有需要處理的事項：回覆 HEARTBEAT_OK
```

---

## 每日（Daily — 今天第一次 heartbeat 執行）

```
□ 昨天有什麼值得記憶的事情？
  → 有：補充到 memory/昨天日期.md（若昨天沒寫的話）

□ 今天是否有已知的排程或待辦？
  → 有：記錄在 memory/今天日期.md 作為開場脈絡
```

---

## 每週一（Weekly — 週一第一次 heartbeat 執行）

```
□ 讀最近 7 天的 memory/*.md
□ 按照 WEEKLY_REVIEW.md 的清單執行完整週度反思：
  1. 識別重複主題
  2. 更新 MEMORY.md（精煉，不增肥）
  3. 更新 GROWTH_LOG.md（記錄失誤 + 學習）
  4. 評估技能缺口
  5. 設定下週意圖

□ 完成後回覆週度反思摘要（≤ 100 字）
```

---

## 每月第一個週一（Monthly — 月初第一個週一）

> **月度蒸餾比週度反思重，需要更多 token。**
> 若 30 天的 memory/ 超過 20 個檔案，直接用 `sessions_spawn` 卸載給子代理人。

```
□ 估算工作量：
  - memory/ 檔案數 ≤ 20 → 直接執行（見下）
  - memory/ 檔案數 > 20 → 用 sessions_spawn（見後）

□ 直接執行路徑（≤ 20 個檔案）：
  1. 讀最近 30 天的 memory/*.md 和 MEMORY.md
  2. 更新 bank/ 知識庫：
     - 新客觀事實 → bank/world.md
     - 值得記錄的活動 → bank/experience.md
     - 新觀點或信心變化 → bank/opinions.md
     - 新的重要人物/專案 → bank/entities/<slug>.md
  3. SOUL.md 評估（個性、邊界、過時規則）
  4. 更新 GROWTH_LOG.md 統計摘要表格
  5. 回覆月度反思摘要（≤ 150 字）
```

子代理人路徑（memory/ > 20 個檔案），使用 `sessions_spawn` tool 呼叫：

```json
{
  "task": "執行月度知識蒸餾。1. 讀取 workspace 中最近 30 天的 memory/*.md。2. 識別新的客觀事實（工具、環境、使用者偏好）→ 更新 bank/world.md。3. 識別值得記錄的活動 → 更新 bank/experience.md。4. 識別新觀點或信心變化 → 更新 bank/opinions.md。5. 若有新的重要人物或專案 → 在 bank/entities/ 建立或更新頁面。完成後回傳：更新了哪些檔案、哪些知識是新增的、哪些模式首次出現。",
  "label": "monthly-distillation",
  "thinking": "low",
  "runTimeoutSeconds": 600,
  "cleanup": "keep"
}
```

```
□ 子代理人完成後（子代理人路徑）：
  - 讀取子代理人的回傳摘要
  - 根據摘要更新 SOUL.md（若有需要）
  - 更新 GROWTH_LOG.md 統計摘要
  - 回覆月度反思摘要（≤ 150 字）
```

---

## 執行注意事項

- **週度反思優先於一般 HEARTBEAT_OK**：若今天是週一，週度反思比快速確認更重要
- **不要在 heartbeat 中執行破壞性操作**：讀、寫、分析可以，刪除或推送到外部要謹慎
- **長任務用子代理人**：月度蒸餾若預計超過 3 分鐘，spawn 一個子代理人處理
- **保持精簡**：MEMORY.md 應該越寫越精，不是越寫越長

---

*此 HEARTBEAT.md 與 `docs/agent-growth-blueprint.md` 中的成長框架對應。*
*若需要調整節奏（例如改為雙週反思），修改「每週一」區塊的觸發條件。*
