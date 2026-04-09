---
name: continue
description: 依據 docs/project-spec.md 的進度，自動選出下一個未完成的優先任務並開始實作
---

讀取 `docs/project-spec.md`，找出所有 `⬜ 未開始` 或 `🟡 進行中` 的任務。

依照以下優先順序選出下一個要做的 Task（選該 Story 中第一個 `⬜ 未開始` 的項目）：

Phase 1：S02 → S04 → S11 → S12
Phase 2：S06 → S08 → S05 → S10
Phase 3：S07 → S09 → S13
Phase 4：S14

宣告計畫（Story、Task 編號、一句話目標、預計影響的檔案），然後開始實作。

實作規則：
- 每完成一個邏輯單元後執行 `bash check.sh`，立即修正語法錯誤
- 功能完成後 STOP，輸出：
  - **功能描述**：做了什麼、怎麼運作
  - **測試案例表**：步驟與預期結果
  - 結尾固定加：`✋ 請測試以上案例，確認後告訴我`
- 等待用戶確認，不要自行繼續下一個 Task
- 用戶確認通過後立即更新 `docs/project-spec.md` 對應任務狀態為 `✅ 完成`
- 不執行 git commit，除非用戶明確要求
