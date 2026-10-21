---
name: delegate
description: ai-os 專案決定要派子 Agent（ai-os:builder／tester／reviewer 或內建的）時讀：什麼情況派誰、派工 prompt 要寫什麼、子 Agent 只 git add 不 commit、派 reviewer 前要準備的材料、修兩次不過時怎麼辦、新增專屬角色。
---

# 子 Agent 委派

預設主 Agent 自己做（共用規則「怎麼做事」）；這裡只講決定要派之後怎麼派。

## 什麼時候派

| 情況 | 派誰 |
|---|---|
| 需要大量讀檔才能回答的探索（找某個功能散在哪、理解陌生的程式碼）| 內建 `Explore` |
| 真正能同時進行、互不相干的工作（兩者不改同一批檔）| `ai-os:builder`，或內建 general-purpose |
| 碰紅線的改動做完後的獨立審查 | `ai-os:reviewer`（或 `/code-review`）|
| 階段功能 3 個以上或涉及紅線的設計文件審查 | `ai-os:reviewer`（模式二）|
| 一次要驗收很多畫面、會塞滿主對話的 Playwright 操作 | `ai-os:tester` |

不派：幾個步驟就能做完的事；為了再驗證一次自己剛做完的工作。

## 派工 prompt 要寫什麼

子 Agent 看不到這段對話，也不讀專案 CLAUDE.md 與共用規則，prompt 要自給自足：
- 要做什麼、完成標準（有規格就給 `_管理/specs/{功能名}.md` 的路徑）
- 要讀的檔（完整路徑）；STACK_RULES 在 `_管理/常駐/專案規格.md`
- 本次的預先核准範圍（從 `方案紀錄.md` 速查表摘出，例：可以建哪些資料表）；沒有就寫「無」
- 資料庫是否已過界線（已上線或已有真資料）；已過就附測試庫切換方式
- 修 bug 沒有規格時：附「重現步驟＋預期結果」
- 只附這個任務直接需要的前情，不貼整段歷史

## commit 分工

| 誰 | 做什麼 |
|---|---|
| 子 Agent | 驗證通過才 `git add <明確檔案清單>`（不用 `git add -A`），不 commit；驗證失敗連 add 都不做 |
| 主 Agent | `git diff --cached --name-only` 看子 Agent 動了哪些檔，有不相干的就問清楚；需要的驗證都過了才統一 commit |

## 派 reviewer 前

reviewer 不能跑指令，主 Agent 先準備好材料：
- 單次改動：給 `git diff --cached --name-only` 的檔案清單，它直接讀工作區的檔
- 整個分支：先 `git diff <分支起點>..HEAD > _管理/全分支diff.txt`（暫存檔，審完刪掉，不 commit），並貼上全部測試的實跑輸出
- 需要套件漏洞掃描（如 `npm audit`）時，主 Agent 先跑、貼上輸出

只處理會影響正確性、安全或需求的發現；風格建議記下即可，不必逐條追。

## 修不好時

同一個問題修兩次還不過 → 停下，用三句話告訴使用者（發生什麼事、影響、建議），一起看是不是做法本身有問題。不要一直換人重派。

## 沒有適合的角色時

- 別的功能也會需要同類工作（AI 整合、爬蟲、支付…）→ 複製 `${CLAUDE_PLUGIN_ROOT}/agents/builder.md` 改成新角色（改 `name`、`description`、工作內容；保留 `omitClaudeMd: true` 與「需要先回報」那段紅線，它看不到共用規則）。所有 ai-os 專案都用得到 → 放進外掛的 `agents/`；只有這個專案用 → 放專案的 `.claude/agents/`，並在 `_管理/開案確認.md`「子 Agent 組合」登記
- 只用這一次 → 用內建 general-purpose 派，prompt 寫清楚只能改哪些檔、哪些事不能做。涉及紅線（安全性、資料庫結構、部署、金流）的工作不用這種方式，改建角色檔
